# app/controllers/patients_controller.rb
class PatientsController < ApplicationController
  before_action :require_server, :delete_current_patient_id

  def index
    @pagy, @patients = pagy_array(fetch_and_cache_patients, items: 10)
    flash.now[:notice] = 'No patient found' if @patients.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @patients = []
  end

  def show
    @patient = fetch_and_cache_patient(params[:id])
    raise 'Unable to find patient' unless @patient

    session[:patient_id] = @patient.id
    retrieve_current_patient_resources
    set_resources_count
    retrieve_practitioner_roles_and_orgs

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('patient', partial: 'patients/patient')
      end
    end
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patients_path
  end

  def sync_patient_record
    Rails.cache.clear
    session[:patient_id] = params[:id]
    record = retrieve_current_patient_resources
    if record.present?
      flash[:notice] = 'Patient record synced successfully!'
    else
      flash[:danger] = 'Failed to sync Patient record!'
    end

    respond_to do |format|
      format.turbo_stream { redirect_back(fallback_location: patient_path(params[:id])) }
      format.html { redirect_back(fallback_location: patient_path(params[:id])) }
    end
  end

  private

  def fetch_and_cache_patients
    clear_cache_if_query_changed
    session[:previous_query] = params[:query_id].present? || params[:query_name].present?

    Rails.cache.fetch(cache_key_for_patients) do
      bundle_entries = fetch_patients

      bundle_entries.map { |entry| Patient.new(entry) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing FHIR Patients:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise 'Error fetching or parsing patients from FHIR server. Check logs.'
    end
  end

  def fetch_and_cache_patient(patient_id)
    Rails.cache.fetch(cache_key_for_patient(patient_id)) do
      patients = Rails.cache.read(cache_key_for_patients)
      patient = patients&.find { |p| p.id == patient_id }
      unless patient
        fhir_patient = fetch_single_patient(patient_id)
        patient = Patient.new(fhir_patient)
      end

      patient
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing patient:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise 'Error fetching or parsing patient from FHIR server. Check logs.'
    end
  end

  def clear_cache_if_query_changed
    return unless params[:query_id].present? || params[:query_name].present? || session[:previous_query]

    Rails.cache.delete(cache_key_for_patients)
  end
end
