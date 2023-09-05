# frozen_string_literal: true

# app/controllers/patients_controller.rb
class PatientsController < ApplicationController
  before_action :require_server

  def index
    session.delete(:patient_id)
    @pagy, @patients = pagy_array(fetch_and_cache_patients, items: 10)
    flash.now[:notice] = 'No patient found' if @patients.empty?
    render layout: false # For optimization!
  rescue StandardError => e
    flash.now[:danger] = e.message
    @patients = []
    render layout: false # For optimization!
  end

  def show
    @patient = fetch_and_cache_patient(params[:id])
    session[:patient_id] = @patient.id
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to pages_patients_path
  end

  private

  def fetch_and_cache_patients
    clear_cache_if_query_changed
    session[:previous_query] = params[:query].present?

    Rails.cache.fetch(cache_key_for_patients, expires_in: 5.minutes) do
      response = fetch_patients_by_name
      entries = response.resource.entry.map(&:resource)

      entries.map { |entry| Patient.new(entry) }
    rescue StandardError
      raise "Error fetching patients from FHIR server. Status code: #{response&.response&.dig(:code)}"
    end
  end

  def fetch_and_cache_patient(patient_id)
    Rails.cache.fetch(cache_key_for_patient(patient_id), expires_in: 5.minutes) do
      patients = Rails.cache.read(cache_key_for_patients)
      patient = patients&.find do |p|
        p.id == patient_id
      end || Patient.new(@client.read(FHIR::Patient, patient_id)&.resource)
      raise "Unable to fetch patient with id #{patient_id} from FHIR server." if patient.nil?

      patient
    rescue StandardError
      raise "Unable to fetch patient with id #{patient_id} from FHIR server."
    end
  end

  def clear_cache_if_query_changed
    return unless params[:query].present? || session[:previous_query]

    Rails.cache.delete(cache_key_for_patients)
  end

  def cache_key_for_patients
    "patients_#{session_id}"
  end

  def cache_key_for_patient(patient_id)
    "fhir_patient_#{patient_id}_#{session_id}"
  end

  def fetch_patients_by_id
    @client.search(FHIR::Patient, search: { parameters: { _id: params[:query] } })
  end

  def fetch_patients_by_name
    response = fetch_patients_by_id
    return response if response&.resource&.entry&.size.to_i.positive?

    @client.search(FHIR::Patient, search: { parameters: { name: params[:query] } })
  end
end
