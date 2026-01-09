# app/controllers/patients_controller.rb
class PatientsController < ApplicationController
  before_action :require_server
  before_action :delete_current_patient_id, except: %i[sync_patient_record update]

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
    retrieve_other_resources

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

    if PatientRecordCache.patient_record_exists?(patient_id) &&
       PatientRecordCache.get_last_sync_time(patient_id)

      last_sync_time = PatientRecordCache.get_last_sync_time(patient_id)
      Rails.logger.info("Last sync time for patient #{patient_id}: #{last_sync_time}")

      begin
        Rails.logger.info("Fetching updates for patient #{patient_id} since #{last_sync_time}")
        new_resources = fetch_single_patient_record(patient_id, 500, last_sync_time)

        if new_resources.present?
          PatientRecordCache.update_patient_record(patient_id, new_resources)
          flash[:notice] = "Patient record synced successfully! Updated #{new_resources.size} resources."
        else
          flash[:notice] = I18n.t('controllers.patients.sync_no_changes')
        end
      rescue StandardError => e
        Rails.logger.error("Error syncing patient record: #{e.message}")
        PatientRecordCache.clear_patient_record(patient_id)
        retrieve_current_patient_resources
        flash[:notice] = I18n.t('controllers.patients.sync_full')
      end
    else
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

  def update
    patient_id = params[:id]

    begin
      fhir_patient = get_patient(patient_id)&.fhir_resource

      unless fhir_patient
        flash[:danger] = I18n.t('controllers.patients.not_found_error')
        redirect_to patients_path
        return
      end

      update_patient_attributes(fhir_patient, patient_params)

      updated_resource = update_resource(fhir_patient)

      if updated_resource.present?
        PatientRecordCache.update_patient_record(patient_id, [updated_resource])
        @patient = Patient.new(updated_resource)
        flash[:success] = I18n.t('controllers.patients.update_success')
      else
        flash[:danger] = I18n.t('controllers.patients.update_error')
      end
    rescue StandardError => e
      Rails.logger.error("Error updating patient: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      flash[:danger] = "Error updating patient: #{e.message}"
      redirect_to patients_path
      return
    end

    respond_to do |format|
      format.html { redirect_to patient_path(patient_id) }
      format.turbo_stream do
        flash.now[:success] = flash[:success] if flash[:success]
        flash.now[:danger] = flash[:danger] if flash[:danger]

        # Set up variables for the patient partial
        session[:patient_id] = patient_id
        retrieve_current_patient_resources
        set_resources_count
        retrieve_other_resources

        render turbo_stream: [
          turbo_stream.replace('flash', partial: 'shared/flash_messages'),
          turbo_stream.replace('patient', partial: 'patients/patient')
        ]
      end
    end
  end

  private

  def patient_params
    params.require(:patient).permit(:first_name, :last_name, :dob, :gender, :address, :phone, :email)
  end

  def update_patient_attributes(fhir_patient, attributes)
    update_name(fhir_patient, attributes)
    fhir_patient.birthDate = attributes[:dob] if attributes[:dob].present?
    fhir_patient.gender = attributes[:gender] if attributes[:gender].present?
    update_address(fhir_patient, attributes[:address]) if attributes[:address].present?
    update_telecom(fhir_patient, 'phone', attributes[:phone]) if attributes[:phone].present?
    update_telecom(fhir_patient, 'email', attributes[:email]) if attributes[:email].present?

    fhir_patient
  end

  def update_name(fhir_patient, attributes)
    if fhir_patient.name.present?
      name = fhir_patient.name.first
      name.given = [attributes[:first_name]] if attributes[:first_name].present?
      name.family = attributes[:last_name] if attributes[:last_name].present?
    else
      fhir_patient.name = [
        FHIR::HumanName.new(
          given: [attributes[:first_name]],
          family: attributes[:last_name],
          use: 'official'
        )
      ]
    end
  end

  def update_address(fhir_patient, address_text)
    address = extract_address_parts(address_text)
    address_item = FHIR::Address.new(
      period: { start: Time.now.iso8601 },
      line: [address[:street]],
      city: address[:city],
      state: address[:state],
      postalCode: address[:postal_code],
      country: address[:country]
    )
    fhir_patient.address = [address_item]
  end

  def extract_address_parts(address_text)
    parts = address_text.split(',').map(&:strip)
    {
      street: parts[0] || '',
      city: parts[1] || '',
      state: parts[2] || '',
      postal_code: parts[3] || '',
      country: parts[4] || ''
    }
  end

  def update_telecom(fhir_patient, system, value)
    telecom = fhir_patient.telecom || []
    existing = telecom.find { |t| t.system == system }

    if existing
      existing.value = value
    else
      telecom << FHIR::ContactPoint.new(
        system: system,
        value: value,
        use: 'home'
      )
    end

    fhir_patient.telecom = telecom
  end

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
