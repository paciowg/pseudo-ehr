# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ApplicationHelper
  include Pagy::Backend

  before_action :current_server, :clear_queries

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

  def retrieve_patient
    @patient = Rails.cache.read(cache_key_for_patient(session[:patient_id]))
    return unless @patient.nil?

    reset_session
    Rails.cache.clear
    flash[:danger] = 'Session has expired. Please reconnect!'
    redirect_to root_path
  end

  def cache_key_for_patients
    "patients_#{session_id}"
  end

  def cache_key_for_patient(patient_id)
    "fhir_patient_#{patient_id}_#{session_id}"
  end
end
