# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  before_action :set_current_server, only: %i[launch_server]

  # GET /sessions/new
  def new
    return unless server_present?

    msg = "Client already connected to fhir_server #{@current_server.base_url}"
    flash[:notice] = msg
    # Where to redirect depends on the context of your app. Change as needed to match your logic.
    redirect_to patients_path
  end

  # POST /launch
  def launch_server
    # Where to redirect depends on the context of your app. Change as needed to match your logic.
    flash[:success] = I18n.t('controllers.sessions.connected') unless @current_server.authenticated_access?
    redirect_to patients_path and return unless @current_server.authenticated_access?

    state = SecureRandom.uuid
    session[:code_verifier] = SecureRandom.urlsafe_base64(64)
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(session[:code_verifier])).gsub(/=+$/, '')
    server_auth_url = "#{@current_server.authorization_url}?response_type=code&redirect_uri=#{login_url}"
    server_auth_url += "&aud=#{@current_server.base_url}&state=#{state}&scope=#{@current_server.scope}&client_id=#{@current_server.client_id}" # rubocop:disable Layout/LineLength
    server_auth_url += "&code_challenge=#{code_challenge}&code_challenge_method=S256"

    redirect_to server_auth_url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.info("Error launching server: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    reset_session
    flash[:danger] = "Failed to obtain authorization code: #{e.message}"
    redirect_to root_path
  end

  # GET /login
  def login
    if params[:error].present? # Authorization Failure
      flash[:danger] = "Authorization Failure: #{params[:error]} - #{params[:error_description]}"
      redirect_to root_path
    else
      raise 'No server to connect to: Please connect.' unless server_present?

      args = { fhir_server: @current_server, new_session: false, code: params[:code], redirect_url: login_url,
               code_verifier: session[:code_verifier] }
      @client = FhirClientService.new(**args).client

      flash[:success] = I18n.t('controllers.sessions.authenticated')
      # Where to redirect depends on the context of your app. Change as needed to match your logic.
      # if withing patient or user context, the patient id or user id will be provided in the authentication response.
      redirect_to patients_path
    end
  rescue StandardError => e
    Rails.logger.info("Error in login: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    reset_session
    flash[:danger] = I18n.t('controllers.sessions.auth_error')
    redirect_to root_path
  end

  # GET /disconnect
  def disconnect_server
    reset_session
    Rails.cache.clear
    clear_all_data
    @client = nil
    if @current_server&.authenticated_access?
      @current_server.update!(
        access_token: nil,
        refresh_token: nil,
        access_token_expires_at: nil
      )
    end
    @current_server = nil
    flash[:success] = I18n.t('controllers.sessions.disconnected')
    redirect_to root_path
  end

  private

  def fhir_server_params
    params.permit(:name, :base_url, :client_id, :client_secret, :scope, :authorization_url, :token_url,
                  :authenticated_access)
  end

  def set_current_server
    @current_server = FhirServer.find_by(base_url: fhir_server_params[:base_url])
    @current_server = FhirServer.new(fhir_server_params) if @current_server.blank?
    FhirClientService.new(fhir_server: @current_server, new_session: true)
    # Retrieve the smart configuration for auth access if not provided
    if @current_server.new_record? && !@current_server.save && @current_server.authenticated_access?
      options = retrieve_smart_config
      @current_server.authorization_url = options['authorization_endpoint']
      @current_server.token = options['token_endpoint']
      @current_server.scope = options['scopes_supported']&.join(' ')
      @current_server.save!
    end
    session[:fhir_server_url] = @current_server.base_url
  rescue StandardError => e
    reset_session

    if @current_server.errors.present?
      flash.now[:danger] = e.message
      render :new
    else
      flash[:danger] = e.message
      redirect_to root_path
    end
  end

  def retrieve_smart_config
    response = RestClient.get("#{@current_server.base_url}/.well-known/smart-configuration")
    JSON.parse(response.body)
  rescue StandardError => e
    msg = 'Unable to retrieve smart-configuration metadata. '
    msg << "Please provive the server's authorization_url, token_url and scope for auth access"
    raise "#{msg}: #{e.message}"
  end
end
