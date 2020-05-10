################################################################################
#
# FHIR Server Interaction
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class FhirServerInteraction

  def initialize(url = nil, oauth2_id = nil, oauth2_secret = nil)
    # Default to HAPI's public testing FHIR server
    @base_server_url = DEFAULT_SERVER
  
    # TODO - SET OAUTH2 ID AND OAUTH2 SECRET IF SERVER USES OAUTH2 AUTHENTICATION
    @oauth2_id = 'example'
    @oauth2_secret = 'secret'

    connect(url, oauth2_id, oauth2_secret)
  end

  #-----------------------------------------------------------------------------

  def connect(url = nil, oauth2_id = nil, oauth2_secret = nil)
    @base_server_url = url unless url.nil?
    @oauth2_id = oauth2_id unless oauth2_id.nil?
    @oauth2_secret = oauth2_secret unless oauth2_secret.nil?

    @client = FHIR::Client.new(@base_server_url)
    options = @client.get_oauth2_metadata_from_conformance

    unless options.blank?
      @client.set_oauth2_auth(@oauth2_id, @oauth2_secret, options[:authorize_url], 
          options[:token_url], options[:site])
    end

    FHIR::Model.client = @client
  end
  
  #-----------------------------------------------------------------------------

  def all_resources(klasses = nil, search = nil)
    replies = all_replies(klasses, search)
    
    if replies.present?
      resources = []

      replies.each do |reply|
        resources.push(reply.resource.entry.collect{ |singleEntry| singleEntry.resource })
      end

      resources.compact!
      resources.flatten(1)
    end
  end

  #-----------------------------------------------------------------------------

  def client
    @client
  end

  #-----------------------------------------------------------------------------

  def base_server_url
    @base_server_url
  end

  #-----------------------------------------------------------------------------
  private
  #-----------------------------------------------------------------------------
  
  def all_replies(klasses = nil, search = nil)
    klasses = coerce_to_a(klasses)
    replies = []

    if klasses.present?
      klasses.each do |klass|
        replies.push(search.present? ? @client.search(klass, search) : @client.read_feed(klass))
        while replies.last
          replies.push(@client.next_page(replies.last))
        end
      end
    else
      replies.push(@client.all_history)
    end

    replies.compact!
    replies.blank? ? nil : replies
  end

  #-----------------------------------------------------------------------------

  def coerce_to_a(object)
    return nil unless object
    object.respond_to?('to_a') ? object.to_a : Array.[](object)
  end

end