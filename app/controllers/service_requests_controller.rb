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
    Rails.cache.fetch(cache_key_for_patient_service_requests(patient_id), expires_in: 1.minute) do
      response = fetch_service_requests_by_patient(patient_id)
      entries = response.resource.entry.map(&:resource)
      fhir_service_requests = entries.select { |entry| entry.resourceType == 'ServiceRequest' }

      fhir_service_requests.map { |entry| ServiceRequest.new(entry, entries) }.sort_by(&:date).reverse
    rescue StandardError => e
      raise "
            Error fetching patient's (#{patient_id}) Service Requests from FHIR server. Status code: #{e.message}
      "
    end
  end

  def fetch_service_requests_by_patient(patient_id)
    search_param = { parameters: {
      patient: patient_id,
      _include: '*'
    } }
    response = @client.search(FHIR::ServiceRequest, search: search_param)
    raise response&.response&.dig(:code) if response&.resource&.entry.nil?

    response
  end

  def cache_key_for_patient_service_requests(patient_id)
    "patient_#{patient_id}_service_requests_#{session_id}"
  end
end
