# app/services/fhir_client_service.rb
# Auth access conformant to Smart-on-Fhir App Launch for Symmetric Client Auth
class FhirClientService
  attr_accessor :fhir_server, :client

  # fhir_server is an instance of FhirServer model that has the base_url, authenticated_access, token_url,
  # client_id, client_secret, scope and access_token, refresh_token & access_token_expires_at attributes
  def initialize(fhir_server:, new_session: false, code: nil, redirect_url: nil, code_verifier: nil)
    @fhir_server = fhir_server
    connect(new_session, code, redirect_url, code_verifier)
  end

  def connect(new_session, code, redirect_url, code_verifier)
    base_url = @fhir_server.is_a?(String) ? @fhir_server : @fhir_server.base_url
    @client = FHIR::Client.new(base_url).tap(&:use_r4)
    # msg = "Couldn't connect to server: unable to fetch capability statement. Verify the base URL is correct."
    # capability_statement = begin
    #   @client&.capability_statement
    # rescue StandardError
    #   Rails.logger.info('Unable to get capability statement')
    # end

    # raise msg if new_session && capability_statement.nil?
    return @client unless @fhir_server.try(:authenticated_access)

    authenticate_fhir_server(code, redirect_url, code_verifier) if code.present?
    refresh_access_token if access_token_expired? && !new_session
    @client.set_bearer_token(@fhir_server.access_token) if @fhir_server.access_token.present?
    @client
  end

  private

  def access_token_expired?
    return false if @fhir_server.access_token_expires_at.blank?

    @fhir_server.access_token_expires_at <= Time.current
  end

  def refresh_access_token
    # Refresh the access token using the refresh token
    oauth2_headers = { content_type: 'application/x-www-form-urlencoded', accept: :json }
    client_credentials = "#{@fhir_server.client_id}:#{@fhir_server.client_secret}"
    oauth2_headers[:Authorization] = "Basic #{Base64.strict_encode64(client_credentials)}"
    oauth2_params = {
      grant_type: 'refresh_token',
      refresh_token: @fhir_server.refresh_token,
      scope: @fhir_server.scope
    }
    response = RestClient.post(@fhir_server.token_url, oauth2_params, oauth2_headers)
    # rubocop:disable Layout/LineLength
    token_data = JSON.parse(response.body)
    @fhir_server.update!(
      access_token: token_data['access_token'],
      refresh_token: token_data['refresh_token'],
      access_token_expires_at: token_data['expires_in'].present? ? Time.current + token_data['expires_in'].to_i.seconds : nil
    )
  rescue RestClient::ExceptionWithResponse => e
    raise "Failed to refresh access token for FHIR server #{@fhir_server.base_url}: #{e.message}. Response: #{e.response}"
  end

  # Support SMART_ON_FHIR CLIENT CONFIDENTIAL SYMMETRIC
  def authenticate_fhir_server(code, redirect_url, code_verifier)
    oauth2_headers = { content_type: 'application/x-www-form-urlencoded', accept: :json }
    client_credentials = "#{@fhir_server.client_id}:#{@fhir_server.client_secret}"
    oauth2_headers[:Authorization] = "Basic #{Base64.strict_encode64(client_credentials)}"

    oauth2_params = {
      code:,
      redirect_uri: redirect_url,
      grant_type: 'authorization_code',
      code_verifier:
    }

    response = RestClient.post(@fhir_server.token_url, oauth2_params, oauth2_headers)

    token_data = JSON.parse(response.body)
    @fhir_server.update!(
      access_token: token_data['access_token'],
      refresh_token: token_data['refresh_token'],
      access_token_expires_at: token_data['expires_in'].present? ? Time.current + token_data['expires_in'].to_i.seconds : nil
    )
    # rubocop:enable Layout/LineLength
  rescue RestClient::ExceptionWithResponse => e
    raise "Failed to obtain access token for #{@fhir_server.base_url}: #{e.response.inspect}"
  rescue JSON::ParserError
    raise "Unable to parse server's authorization response. Response is not a valid JSON"
  end
end
