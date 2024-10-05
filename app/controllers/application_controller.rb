class ApplicationController < ActionController::Base
  include ApplicationHelper
  include Pagy::Backend

  before_action :current_server, :clear_queries

  def server_present?
    !!current_server
  end

  def require_server
    msg = 'No session available. Please connect to a fhir server to get started'
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
    @patient = Rails.cache.fetch(cache_key_for_patient(patient_id)) do
      Patient.new(fetch_single_patient(patient_id))
    rescue StandardError => e
      Rails.logger.error("Error fetching patient: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    return unless @patient.nil?

    flash[:danger] = 'Please select a patient to proceed'
    redirect_to pages_patients_path
  end

  def retrieve_practitioner_roles_and_orgs
    return [] unless patient_id

    Rails.cache.fetch(cache_key_for_practioner_roles) do
      @practitioner_roles ||= fetch_practitioner_roles
    end
  rescue StandardError => e
    Rails.logger.error("Empty bundle or Error fetching practitioner roles:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    []
  end

  def retrieve_current_patient_resources
    return [] unless patient_id

    Rails.cache.fetch(cache_key_for_patient_record(patient_id)) do
      @patient_record ||= fetch_single_patient_record(patient_id)
    end
  rescue StandardError => e
    Rails.logger.error("Error fetching patient #{patient_id} record: #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    []
  end

  def grouped_current_patient_record
    @grouped_current_patient_record ||= retrieve_current_patient_resources.group_by(&:resourceType) || {}
  end

  def cached_resources_type(type)
    grouped_current_patient_record[type] || []
  end

  def find_cached_resource(resource_type, resource_id)
    cached_resources_type(resource_type).find { |res| res.id == resource_id }
  end

  def adi_category_codes
    %w[42348-3 75320-2]
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

  def set_resources_count
    @care_team_count = cached_resources_type('CareTeam').size
    @condition_count = cached_resources_type('Condition').size
    @goal_count = cached_resources_type('Goal').size
    @medication_list_count = cached_resources_type('List').size
    @observation_count = cached_resources_type('Observation').size
    @questionnaire_response_count = cached_resources_type('QuestionnaireResponse').size
    @nutrition_order_count = cached_resources_type('NutritionOrder').size
    @service_request_count = cached_resources_type('ServiceRequest').size
    @adi_count = filter_doc_refs_or_compositions_by_category(
      cached_resources_type('DocumentReference'), adi_category_codes
    ).size
    @toc_count = filter_doc_refs_or_compositions_by_category(cached_resources_type('Composition')).size
  end
end
