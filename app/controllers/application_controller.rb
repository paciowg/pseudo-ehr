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

  ############ Cache Keys ############

  def cache_key_for_patients
    "patients_#{session_id}"
  end

  def cache_key_for_patient(patient_id)
    "fhir_patient_#{patient_id}_#{session_id}"
  end

  def cache_key_for_all_resources_for_patient(patient_id)
    "patient_#{patient_id}_all_resources_#{session_id}"
  end

  def cache_key_for_patient_adis(patient_id)
    "patient_#{patient_id}_adis_#{session_id}"
  end

  def cache_key_for_adi(adi_id)
    "adi_#{adi_id}_#{session_id}"
  end

  def cache_key_for_patient_care_teams(patient_id)
    "patient_#{patient_id}_care_teams_#{session_id}"
  end

  def cache_key_for_patient_conditions(patient_id)
    "patient_#{patient_id}_conditions_#{session_id}"
  end

  def cache_key_for_patient_goals(patient_id)
    "patient_#{patient_id}_goals_#{session_id}"
  end

  def cache_key_for_patient_medication_lists(patient_id)
    "patient_#{patient_id}_medication_lists_#{session_id}"
  end

  def cache_key_for_patient_nutrition_orders(patient_id)
    "patient_#{patient_id}_nutrition_orders_#{session_id}"
  end

  def cache_key_for_patient_observations(patient_id)
    "patient_#{patient_id}_observations_#{session_id}"
  end

  def cache_key_for_patient_questionnaire_responses(patient_id)
    "patient_#{patient_id}_questionnaire_responses_#{session_id}"
  end

  def cache_key_for_patient_service_requests(patient_id)
    "patient_#{patient_id}_service_requests_#{session_id}"
  end

  def cache_key_for_patient_tocs
    "patient_#{params[:patient_id]}_tocs_#{session_id}"
  end
end
