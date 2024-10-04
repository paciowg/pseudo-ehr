# app/controllers/service_requests_controller.rb
class ServiceRequestsController < ApplicationController
  before_action :require_server, :retrieve_patient

  # GET /patients/:patient_id/service_requests
  def index
    @pagy, @service_requests = pagy_array(fetch_and_cache_service_requests(params[:patient_id]),
                                          items: 10)
    flash.now[:notice] = 'Patient has no Service Request yet' if @service_requests.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @service_requests = []
  end

  private

  def fetch_and_cache_service_requests(patient_id)
    Rails.cache.fetch(cache_key_for_patient_service_requests(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_service_requests = cached_resources_type('ServiceRequest')

      if fhir_service_requests.blank?
        entries = fetch_service_requests_by_patient(patient_id)
        fhir_service_requests = entries.select { |entry| entry.resourceType == 'ServiceRequest' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_service_requests.map { |entry| ServiceRequest.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Service Request:\n #{e.message.inspect}")
      raise "Error fetching or parsing patient's Service Requests. Check the log for detail."
    end
  end
end
