# app/controllers/medication_requests_controller.rb
class MedicationRequestsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/medication_requests
  def index
    @pagy, @medication_requests = pagy_array(fetch_patient_medication_requests(params[:patient_id]), items: 10)
    flash.now[:notice] = 'No Medication request found' if @medication_requests.empty?
  rescue StandardError => e
    Rails.logger.error e
    flash.now[:danger] = e.message
    @medication_requests = []
  end

  private

  def fetch_patient_medication_requests(patient_id)
    med_requests = MedicationRequest.filter_by_patient_id(patient_id)
    return sort_med_requests(med_requests) unless MedicationRequest.expired? || med_requests.blank?

    entries = retrieve_current_patient_resources
    fhir_medication_requests = cached_resources_type('MedicationRequest')

    if fhir_medication_requests.blank?
      entries = fetch_medication_requests_by_patient(patient_id, 500, MedicationRequest.updated_at)
      fhir_medication_requests = entries.select { |entry| entry.resourceType == 'MedicationRequest' }
    end

    entries = (entries + retrieve_practitioner_roles).uniq
    fhir_medication_requests.each { |entry| MedicationRequest.new(entry, entries) }

    med_requests = MedicationRequest.filter_by_patient_id(patient_id)
    sort_med_requests(med_requests)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Medication Request:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Error fetching or parsing patient's Medication Request. Check the log for detail."
  end

  def sort_med_requests(med_requests)
    med_requests.sort_by { |medreq| DateTime.parse(medreq.authored_on) || '' }.reverse
  end
end
