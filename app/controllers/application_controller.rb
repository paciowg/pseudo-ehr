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
    @patient = Rails.cache.fetch(cache_key_for_patient(session[:patient_id]))

    return unless @patient.nil?

    flash[:danger] = 'Please select a patient to proceed'
    redirect_to pages_patients_path
  end

  def retrieve_current_patient_resources
    Rails.cache.fetch(cache_key_for_patient_record(session[:patient_id]))
  end

  def grouped_current_patient_record
    retrieve_current_patient_resources&.group_by(&:resourceType) || {}
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

  def filter_doc_refs_or_compositions_by_category(resources, category_codes)
    resources.select do |resource|
      resource.category.any? do |category|
        category.coding.any? do |coding|
          category_codes.include?(coding.code)
        end
      end
    end
  end
end
