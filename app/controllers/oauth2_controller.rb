
class Oauth2Controller < ApplicationController

  # before_action :set_base_server_url
  around_action :set_client

  # GET /oauth2/start
  # follows PatientServerController#create to reset HTTP headers
  def start
  end

  # POST /oauth2/register
  # preform client registration as specified in security spec
  def register
    @base_server_url = "http://localhost:3000"
    rsa_private_key = OpenSSL::PKey::RSA.generate 2048
    rsa_public_key = rsa_private_key.public_key

	payload = {
		iss: "#{root_url}",
		sub: "client_id?", # TODO
		aud: @base_server_url + '/oauth/registration', # TODO: fetch from capability statement
		#exp: (now + 4.5).to_i, # TODO
		iat: DateTime.now.to_i,
		jti: SecureRandom.base58,
		client_name: "encode.rb", # TODO
		redirect_uris: "[\"#{oauth2_redirect_url}\"]",
		contacts: '["mailto:ashankland@mitre.org"]',
		logo_uri: "https://hl7.org/fhir/assets/images/fhir-logo.png",
		grant_types: "authorization_code",
		response_types: '["code"]',
		token_endpoint_auth_method: "private_key-jwt",
		scope: "system/Patient.read system/Observation.read"
	}

    x509_cert_chain = [ self_signed_x509_cert(rsa_private_key, rsa_public_key) ] # TODO: load PEM cert chain option
    Rails.logger.info("cert chain type: ")
    Rails.logger.info(x509_cert_chain.class)
	token = JWT.encode(payload, rsa_private_key, 'RS256', { x5c: x509_cert_chain })
  body = {
    redirect_uris: "[\"#{oauth2_redirect_url}\"]",
    software_statement: token,
    scope: "system/Patient.read system/Observation.read"
  }
	response = RestClient.post(payload[:aud], body, nil)

	# TODO check response
    Rails.logger.info "== OAUTH2 REGISTER RESPONSE =="
    Rails.logger.info response.to_json
    Rails.logger.info "=============================="

	redirect_to root_url
  end

  # GET /oauth2/restart
  # initiate actual oauth2 protocol - authorization code flow
  def restart
	options = @client.get_oauth2_metadata_from_conformance

	if options.blank?
		options[:authorize_url] = @base_server_url.join('oauth','authorize')
		options[:token_url] = @base_server_url.join('oauth','token')

		flash.alert = "Detected no oauth2 endpoints in server's compatability statement. You must add this to compatability statement. Defaulting to #{options}."
		Rails.logger.error "No OAuth2 endpoints found in compatability statement"
	end
    session[:token_url] = options[:token_url]

    @auth_params = {
        :response_type => 'code',
        :client_id => ENV["CLIENT_ID"],
        :redirect_uri => oauth2_redirect_url,
        :state => SecureRandom.uuid,
        :aud => @base_server_url
    }

    @authorize_url = options[:authorize_url] + "?" + @auth_params.to_query
	#Rails.logger.debug "== AUTHORIZATION URL =="
	#Rails.logger.debug @authorize_url
	#Rails.logger.debug "======================="

	session[:authorize_url] = @authorize_url

    redirect_to @authorize_url, allow_other_host: true
  end

  # GET /oauth2/redirect
  # oauth2 redirect endpoint (for both authorize and token)
  def redirect
	Rails.logger.debug "HIT CLIENT REDIRECT"

    @code = params[:code]
    @access_token = params[:access_token]

    if @code.present?
        @state = params[:state] # TODO: validate state

		@token_params = {
            :grant_type => 'authorization_code',
            :code => @code,
            :redirect_uri => oauth2_redirect_url,
            :client_id => ENV["CLIENT_ID"],
            :client_secret => ENV["CLIENT_SECRET"]
        }
        @token_url = session[:token_url]
		#Rails.logger.debug "== GETTING TOKEN =="
		#Rails.logger.debug @token_url
		#Rails.logger.debug @token_params
		#Rails.logger.debug "==================="

        begin
            @response = RestClient.post(@token_url, @token_params);
            #Rails.logger.debug "== POST /token =="
            #Rails.logger.debug @response.body
            #Rails.logger.debug "================="
        rescue RestClient::ExceptionWithResponse => e
            flash.now.alert = "Oauth server could not handle token request. Error: #{e}"
            Rails.logger.error "Failed POST #{@token_url}, error #{e}"
            render :debug and return
        end

        @token = JSON.parse(@response.body)["access_token"]
        session[:access_token] = @token
        flash.now.notice = "Obtained access token!"

        @client = FHIR::Client.new(@base_server_url)
        @client.set_bearer_token(@token)
    else
		Rails.logger.error "oauth2/redirect/ endpoint triggered but missing code parameter"
        flash.now.alert = "oauth2/redirect/ endpoint triggered without code parameter, params: #{params}"
        render(:debug, status: 400) and return
   	end

	# renders app/views/oauth2/redirect.html.erb with success message
  end

  private

  def set_client
	@client = FHIR::Client.new(@base_server_url)
	yield
  end

  def self_signed_x509_cert(private_key, public_key)
    subject = "/C=US/CN=Test"

    cert = OpenSSL::X509::Certificate.new
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
    cert.not_before = Time.now
    cert.not_after = Time.now + 365 * 24 * 60 * 60
    cert.public_key = public_key
    cert.serial = 0 # In production, this should be a secure random unique positive integer
    cert.version = 2

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert.extensions = [
      ef.create_extension("basicConstraints","CA:TRUE", true),
      ef.create_extension("subjectKeyIdentifier", "hash"),
      # ef.create_extension("keyUsage", "cRLSign,keyCertSign", true),
    ]
    cert.add_extension ef.create_extension("authorityKeyIdentifier",
                                           "keyid:always,issuer:always")

    cert.sign private_key, OpenSSL::Digest::SHA256.new

    cert.to_pem
  end



end
