# frozen_string_literal: true

# app/controllers/patients_controller.rb
class PatientsController < ApplicationController
  before_action :require_server

  def index
    session.delete(:patient_id)
    @pagy, @patients = pagy_array(fetch_and_cache_patients, items: 10)
    flash.now[:notice] = 'No patient found' if @patients.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @patients = []
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
    session[:previous_query] = params[:query_id].present? || params[:query_name].present?

    Rails.cache.fetch(cache_key_for_patients, expires_in: 1.minute) do
      response = fetch_patients
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
    return unless params[:query_id].present? || params[:query_name].present? || session[:previous_query]

    Rails.cache.delete(cache_key_for_patients)
  end

  def fetch_patients_by_id
    @client.search(FHIR::Patient, search: { parameters: { _id: params[:query_id] } })
  end

  def fetch_patients_by_name
    @client.search(FHIR::Patient, search: { parameters: { name: params[:query_name], active: true } })
  end

  def fetch_patients
    if params[:query_id].present?
      fetch_patients_by_id
    elsif params[:query_name].present?
      fetch_patients_by_name
    else
      @client.read_feed(FHIR::Patient)
    end
  end
end
