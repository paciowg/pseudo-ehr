# app/controllers/service_requests_controller.rb
class ServiceRequestsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/service_requests
  def index
    @pagy, @service_requests = pagy_array(fetch_service_requests(params[:patient_id]),
                                          items: 10)
    flash.now[:notice] = I18n.t('controllers.service_requests.no_requests') if @service_requests.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @service_requests = []
  end

  private

  def fetch_service_requests(patient_id)
    srs = ServiceRequest.filter_by_patient_id(patient_id).reject { |sr| sr.code == '--' }
    return srs unless ServiceRequest.expired? || srs.blank?

    entries = retrieve_current_patient_resources
    fhir_service_requests = cached_resources_type('ServiceRequest')

    if fhir_service_requests.blank?
      Rails.logger.info('Service requests not found in patient record cache, fetching directly')
      entries = fetch_service_requests_by_patient(patient_id, 500, ServiceRequest.updated_at)
      fhir_service_requests = entries.select { |entry| entry.resourceType == 'ServiceRequest' }
    end

    entries = (entries + retrieve_practitioner_roles).uniq
    fhir_service_requests.each { |entry| ServiceRequest.new(entry, entries) }

    ServiceRequest.filter_by_patient_id(patient_id).reject { |sr| sr.code == '--' }
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Service Request:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))

    raise "Error fetching or parsing patient's Service Requests. Check the log for detail."
  end
end
