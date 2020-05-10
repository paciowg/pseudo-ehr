##
# +SessionHandler+ provides basic server-side session-specific utilities for reference 
# implementation FHIR clients
# 
# All methods require a +session_id+ parameter to know which session they are dealing with, 
# generally speaking this should come from a +session.id+ call from a +Controller+
#
# <b>Do not initialize this class, reference it statically</b>

class SessionHandler


  ##
  # Establishes connection to a FHIR server by instantiating +FhirServerInteraction+
  # 
  # Updates active timer for this session's connection to prevent premature pruning
  #
  # *Params*
  #
  # * +session_id+ - indicates which session to establish a +SessionHandler+ for (use 
  #   +session.id+)
  #
  # * +url+ - _Optional_ _param_, overrides <code>@server_url</code> from 
  #   +FhirServerInteraction+ and replaces it as the default connection url for this session
  #
  # * +oauth2_id+ - _Optional_ _param_, overrides <code>@oauth2_id</code> from 
  #   +FhirServerInteraction+ and replaces it as the default OAuth2 ID for this session
  #
  # * +oauth2_secret+ - _Optional_ _param_, overrides <code>@oauth2_secret</code> from 
  #   +FhirServerInteraction+ and replaces it as the default OAuth2 secret for this session

  def self.establish(session_id, url = nil, oauth2_id = nil, oauth2_secret = nil)
    if established?(session_id)
      client = Rails.cache.read(session_id.public_id + "--connection")
    else
      client = FhirServerInteraction.new(url, oauth2_id, oauth2_secret)
    end
    store(session_id, "connection", client)
  end


  ##
  # Resets +FhirServerInteraction+ connection according to the provided params
  # 
  # Updates active timer for this session's connection to prevent premature pruning
  # 
  # *Params*
  #
  # * +session_id+ - indicates which session to reset the connection (use +session.id+)
  #
  # * +url+ - _Optional_ _param_, overrides <code>@server_url</code> from 
  #   +FhirServerInteraction+ and replaces it as the default connection url for this session
  #
  # * +oauth2_id+ - _Optional_ _param_, overrides <code>@oauth2_id</code> from 
  #   +FhirServerInteraction+ and replaces it as the default OAuth2 ID for this session
  #
  # * +oauth2_secret+ - _Optional_ _param_, overrides <code>@oauth2_secret</code> from 
  #   +FhirServerInteraction+ and replaces it as the default OAuth2 secret for this session

  def self.reset_connection(session_id, url = nil, oauth2_id = nil, oauth2_secret = nil)
    new_connection = Rails.cache.read(session_id.public_id + "--connection")
    new_connection.connect(url, oauth2_id, oauth2_id)
    store(session_id, "connection", new_connection)
  end

  def self.disconnect(session_id)
    store(session_id, "connection", nil)
  end

  ##
  # Gets +FHIR::Client+ instance associated with the provided +session_id+
  # 
  # Updates active timer for this session's connection to prevent premature pruning
  # 
  # *Params*
  #
  # * +session_id+ - Indicates which session to get the +FHIR::Client+ from (use +session.id+)
  # 
  # *Returns* - This session's instance of FHIR::Client

  def self.fhir_client(session_id)
    connection = from_storage(session_id, "connection")
    if connection.nil?
      establish(session_id)
      connection = from_storage(session_id, "connection")
    end

    connection.client
  end


  ##
  # Makes search requests of the connected FHIR server for each klass represented in klasses, 
  # and iterates through the resulting bundles to provide an array of every returned resource
  # 
  # Basically a helper method to provide more functionality on top of what the +FHIR::Client+ can 
  # already do
  # 
  # Updates active timer for this session's connection to prevent premature pruning
  # 
  # *Params*
  # 
  # * +session_id+ - Indicates which session's +FHIR::Client+ to use for executing searches (use 
  #   +session.id+)
  # 
  # * +klasses+ - An array of +FHIR::Klass+ types to search for (e.g. <code>[FHIR::Patient, 
  #   FHIR::Practitioner]</code> or <code>[FHIR::Questionnaire]</code>)
  # 
  # * +search+ - _Optional_ _param_, provides search specifications for your resource query. If 
  #   unspecified, returns all resources from server matching +klasses+. If specified, follows 
  #   same format as other +FHIR::Client+ search hashes (e.g. <code>search = { search: { 
  #   parameters: { _count: 50 } } }</code> )
  #
  # *Returns* - An array full of every instance the associated server holds of +klasses+ that, if 
  # specified, match the +search+

  def self.all_resources(session_id, klasses, search = {})
    from_storage(session_id, "connection").all_resources(klasses, search)
  end


  ##
  # Stores +value+ in this sessions in-memory storage to be later retrieved by +key+
  # 
  # *Params*
  # 
  # * +session_id+ - Indicates which session's storage to store +value+ in (use +session.id+)
  # 
  # * +key+ - The key to associate +value+ with for future retrieval
  # 
  # * +value+ - The value to store for future access

  def self.store(session_id, key, value)
    Rails.cache.write(session_id.public_id + "--" + key, value, { expires_in: @expiry_time })
  end


  ##
  # Retrieves a value from storage by its +key+
  # 
  # Updates active timer for this value to prevent premature pruning
  # 
  # *Params*
  #
  # * +session_id+ - Indicates which session's storage to access (use +session.id+)
  # 
  # * +key+ - The key with which the return value was stored
  # 
  # *Returns* - A specific value from storage that was stored with the provided +key+

  def self.from_storage(session_id, key)
    active(session_id, key)
    Rails.cache.read(session_id.public_id + "--" + key)
  end


  ##
  # Updates last active time for value of +key+ to prevent premature pruning. Defaults to refresh 
  # connection if no key is specified.
  # 
  # *Params*
  #
  # * +session_id+ - indicates which session to refresh +key+ active status for (use +session.id+)
  # 
  # * +key+ - _Optional_ _param_, indicates which key to refresh expiration timer for, refreshes  
  #   connection timer if nil/undefined

  def self.active(session_id, key = nil)
    cache_key = session_id.public_id + "--" + (key.nil? ? "connection" : key)
    val = Rails.cache.read(cache_key)
    store(session_id, cache_key, val)
  end

  private

  # This instance variable determines how long the Rails cache will hold onto information
  @expiry_time = 30.minutes

  def self.established?(session_id, key = nil)
    cache_key = session_id.public_id + "--" + (key.nil? ? "connection" : key)
    !(Rails.cache.read(cache_key).nil?)
  end

end