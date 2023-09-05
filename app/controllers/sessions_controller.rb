# frozen_string_literal: true

# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  before_action :require_server, only: %i[login disconnect_server]
  before_action :set_current_server, only: %i[launch_server]

  # GET /sessions/new
  def new
    return unless server_present?

    msg = "Client already connected to fhir_server #{@fhir_server.base_url}"
    flash[:notice] = msg
    # Where to redirect depends on the context of your app. Change as needed to match your logic.
    redirect_to pages_patients_path
  end

  # POST /launch
  def launch_server
    # Where to redirect depends on the context of your app. Change as needed to match your logic.
    redirect_to pages_patients_path and return unless @fhir_server.authenticated_access?

    state = SecureRandom.uuid
    session[:code_verifier] = SecureRandom.urlsafe_base64(64)
    code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(session[:code_verifier])).gsub(/=+$/, '')
    server_auth_url = "#{@fhir_server.authorization_url}?response_type=code&redirect_uri=#{login_url}"
    server_auth_url += "&aud=#{@fhir_server.base_url}&state=#{state}&scope=#{scope}&client_id=#{@fhir_server.client_id}"
    server_auth_url += "&code_challenge=#{code_challenge}&code_challenge_method=S256"

    redirect_to server_auth_url
  rescue StandardError => e
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
      args = { fhir_server: @fhir_server, new_session: false, code: params[:code], redirect_uri: login_url,
               code_verifier: session[:code_verifier] }
      @client = FhirClientService.new(**args)
      flash[:success] = 'Successfully authenticated with server.'
      # Where to redirect depends on the context of your app. Change as needed to match your logic.
      # if withing patient or user context, the patient id or user id will be provided in the authentication response.
      redirect_to pages_patients_path
    end
  rescue StandardError => e
    reset_session
    flash[:danger] = e.message
    redirect_to root_path
  end

  # GET /disconnect
  def disconnect_server
    reset_session
    Rails.cache.clear
    flash[:success] = 'Successfully disconnected client from server'
    redirect_to root_path
  end

  private

  def fhir_server_params
    params.permit(:name, :base_url, :client_id, :client_secret, :scope, :authorization_url, :token_url,
                  :authenticated_access)
  end

  def set_current_server
    @fhir_server = FhirServer.find_by(base_url: fhir_server_params[:base_url])
    @fhir_server = FhirServer.new(fhir_server_params) if @fhir_server.blank?
    FhirClientService.new(fhir_server: @fhir_server, new_session: true)
    # Retrieve the smart configuration for auth access if not provided
    if @fhir_server.new_record? && (!@fhir_server.save && @fhir_server.authenticated_access?)
      options = retrieve_smart_config
      @fhir_server.authorization_url = options['authorization_endpoint']
      @fhir_server.token = options['token_endpoint']
      @fhir_server.scope = options['scopes_supported']&.join(' ')
      @fhir_server.save!
    end
    session[:fhir_server_url] = @fhir_server.base_url
  rescue StandardError => e
    reset_session

    if @fhir_server.errors.present?
      flash.now[:danger] = e.message
      render :new
    else
      flash[:danger] = e.message
      redirect_to root_path
    end
  end

  def retrieve_smart_config
    response = RestClient.get("#{@fhir_server.base_url}/.well-known/smart-configuration")
    JSON.parse(response.body)
  rescue StandardError => e
    msg = 'Unable to retrieve smart-configuration metadata. '
    msg << "Please provive the server's authorization_url, token_url and scope for auth access"
    raise "#{msg}: #{e.message}"
  end
end
