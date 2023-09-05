# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :current_server

  def current_server
    @fhir_server = FhirServer.find_by(base_url: session[:fhir_server_url])
  end

  def server_present?
    !!current_server
  end

  def require_server
    msg = 'No session available. Please connect to a fhir server to get started'
    set_client and return if server_present?

    reset_session
    flash[:danger] = msg
    redirect_to root_path
  end

  def set_client
    @client = FhirClientService.new(fhir_server: current_server).client
  end

  def session_id
    session[:id] ||= Base64.encode64(SecureRandom.random_number(2**64).to_s).chomp
  end
end
