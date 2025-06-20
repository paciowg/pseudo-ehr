# app/controllers/patients_controller.rb
class PatientsController < ApplicationController
  before_action :require_server, :delete_current_patient_id

  def index
    @pagy, @patients = pagy_array(get_patients, items: 10)
    flash.now[:notice] = I18n.t('controllers.patients.no_patients') if @patients.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @patients = []
  end

  def show
    @patient = get_patient(params[:id])
    raise 'Unable to find patient' unless @patient

    session[:patient_id] = @patient.id
    retrieve_current_patient_resources
    set_resources_count
    retrieve_practitioner_roles

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
    patient_id = params[:id]

    clear_models_data_for_patient(patient_id)

    # Check if we have existing data and a last sync time
    if PatientRecordCache.patient_record_exists?(patient_id) &&
       PatientRecordCache.get_last_sync_time(patient_id)

      last_sync_time = PatientRecordCache.get_last_sync_time(patient_id)
      Rails.logger.info("Last sync time for patient #{patient_id}: #{last_sync_time}")

      # Fetch only resources that have changed since last sync
      begin
        Rails.logger.info("Fetching updates for patient #{patient_id} since #{last_sync_time}")
        new_resources = fetch_single_patient_record(patient_id, 500, last_sync_time)

        if new_resources.present?
          # Update the existing record with new resources
          PatientRecordCache.update_patient_record(patient_id, new_resources)
          flash[:notice] = "Patient record synced successfully! Updated #{new_resources.size} resources."
        else
          flash[:notice] = I18n.t('controllers.patients.sync_no_changes')
        end
      rescue StandardError => e
        Rails.logger.error("Error syncing patient record: #{e.message}")
        # If there's an error with incremental sync, fall back to full sync
        PatientRecordCache.clear_patient_record(patient_id)
        retrieve_current_patient_resources
        flash[:notice] = I18n.t('controllers.patients.sync_full')
      end
    else
      # If no existing data or last sync time, do a full sync
      Rails.logger.info("No existing data or last sync time for patient #{patient_id}, doing full sync")
      PatientRecordCache.clear_patient_record(patient_id)
      record = retrieve_current_patient_resources
      if record.present?
        flash[:notice] = I18n.t('controllers.patients.sync_full')
      else
        flash[:danger] = I18n.t('controllers.patients.sync_failed')
      end
    end

    session[:patient_id] = patient_id

    respond_to do |format|
      format.turbo_stream { redirect_back(fallback_location: patient_path(patient_id)) }
      format.html { redirect_back(fallback_location: patient_path(patient_id)) }
    end
  end

  private

  def get_patients
    patients = filter_patients_by_query
    return patients unless Patient.expired? || patients.blank?

    # If not in cache or expired, fetch from FHIR server
    Rails.logger.info('Patients list not found in memory or expired, fetching from server')
    begin
      bundle_entries = fetch_patients
      bundle_entries.each { |entry| Patient.new(entry) }

      filter_patients_by_query
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing FHIR Patients:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise 'Error fetching or parsing patients from FHIR server. Check logs.'
    end
  end

  def get_patient(patient_id)
    patient = Patient.find(patient_id)
    return patient if patient

    begin
      fhir_patient = fetch_single_patient(patient_id)
      patient = Patient.new(fhir_patient)
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing patient:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise 'Error fetching or parsing patient from FHIR server. Check logs.'
    end

    patient
  end

  def filter_patients_by_query
    if params[:query_id].present?
      Patient.filter_by_patient_id(params[:query_id])
    elsif params[:query_name].present?
      Patient.filter_by_name(params[:query_name])
    else
      Patient.all
    end
  end
end
