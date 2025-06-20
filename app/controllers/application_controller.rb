class ApplicationController < ActionController::Base
  include ApplicationHelper
  include Pagy::Backend

  before_action :current_server, :clear_queries

  def server_present?
    !!current_server
  end

  def require_server
    msg = I18n.t('controllers.sessions.no_session')
    set_client and return if server_present?

    reset_session
    @client = nil
    flash[:danger] = msg
    redirect_to root_path
  end

  def set_client
    client
  end

  def delete_current_patient_id
    session.delete(:patient_id)
  end

  def retrieve_patient
    cached_patient = Patient.find(patient_id)

    if cached_patient
      @patient = cached_patient
    else
      Rails.logger.info("Patient #{patient_id} not found in cache, fetching from server")
      begin
        patient_data = fetch_single_patient(patient_id)
        @patient = Patient.new(patient_data)
      rescue StandardError => e
        Rails.logger.error("Error fetching patient: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        @patient = nil
      end
    end

    return unless @patient.nil?

    flash[:danger] = I18n.t('controllers.application.select_patient')
    redirect_to patients_path
  end

  def retrieve_practitioner_roles
    return PractitionerRoleCache.all unless PractitionerRoleCache.expired? || PractitionerRoleCache.all.empty?

    # If not in cache, fetch and store it
    Rails.logger.info('Practitioner roles not found in memory, fetching from server')
    begin
      practitioner_roles = fetch_practitioner_roles(500, PractitionerRoleCache.updated_at)
      PractitionerRoleCache.update_records(practitioner_roles)
      PractitionerRoleCache.all
    rescue StandardError => e
      Rails.logger.error("Empty bundle or Error fetching practitioner roles:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      []
    end
  end

  def retrieve_current_patient_resources
    return [] unless patient_id

    cached_record = PatientRecordCache.get_patient_record(patient_id)
    return cached_record if cached_record

    Rails.logger.info("Patient record not found in memory or expired, fetching from server for patient #{patient_id}")
    begin
      patient_record = fetch_single_patient_record(patient_id)

      PatientRecordCache.store_patient_record(patient_id, patient_record)

      patient_record
    rescue StandardError => e
      Rails.logger.error("Error fetching patient #{patient_id} record: #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      []
    end
  end

  def grouped_current_patient_record
    return {} unless patient_id

    cached_grouped_record = PatientRecordCache.get_grouped_patient_record(patient_id)
    return cached_grouped_record if cached_grouped_record

    retrieve_current_patient_resources

    PatientRecordCache.get_grouped_patient_record(patient_id)
  end

  def cached_resources_type(type)
    # Use a hash to store cached resources by type
    @cached_resources ||= {}
    @cached_resources[type] ||= grouped_current_patient_record[type] || []
  end

  def find_cached_resource(resource_type, resource_id)
    cached_resources_type(resource_type).find { |res| res.id == resource_id }
  end

  def adi_category_codes
    %w[42348-3 75320-2]
  end

  def toc_category_codes
    %w[18761-7]
  end

  def filter_doc_refs_or_compositions_by_category(resources, category_codes = [])
    resources.select do |resource|
      if category_codes.blank?
        resource.category.blank?
      else
        resource.category.any? do |category|
          category.coding.any? do |coding|
            category_codes.include?(coding.code)
          end
        end
      end
    end
  end

  def filter_non_adi_docs(resources)
    resources - filter_doc_refs_or_compositions_by_category(resources, adi_category_codes)
  end

  PATIENT_MODELS = [
    AdvanceDirective, AllergyIntolerance, CarePlan, CareTeamParticipant, CareTeam,
    Composition, Condition, DiagnosticReport, DocumentReference, Goal,
    MedicationList, MedicationRequest, MedicationStatement, NutritionOrder,
    Observation, Procedure, QuestionnaireResponse, ServiceRequest
  ].freeze
  OTHER_MODELS = [Patient, PatientRecordCache, PractitionerRoleCache].freeze

  def clear_models_data_for_patient(patient_id)
    PATIENT_MODELS.each { |model| model.clear_patient_data(patient_id) }
  end

  def clear_all_data
    PATIENT_MODELS.each(&:clear_data)
    OTHER_MODELS.each(&:clear_data)
  end

  def set_resources_count
    return unless patient_id

    @care_team_count = cached_resources_type('CareTeam').size
    @condition_count = cached_resources_type('Condition').size
    @goal_count = cached_resources_type('Goal').size
    @medication_list_count = cached_resources_type('List').size
    @medication_requests_count = cached_resources_type('MedicationRequest').size
    @procedures_count = cached_resources_type('Procedure').size
    @diagnostic_reports_count = cached_resources_type('DiagnosticReport').size
    @document_references_count = filter_non_adi_docs(cached_resources_type('DocumentReference')).size
    @observation_count = cached_resources_type('Observation').size
    @questionnaire_response_count = cached_resources_type('QuestionnaireResponse').size
    @nutrition_order_count = cached_resources_type('NutritionOrder').size
    @service_request_count = cached_resources_type('ServiceRequest').size
    @adi_count = filter_doc_refs_or_compositions_by_category(
      cached_resources_type('DocumentReference'), adi_category_codes
    ).size
    @toc_count = filter_doc_refs_or_compositions_by_category(
      cached_resources_type('Composition'), toc_category_codes
    ).size
  end
end
