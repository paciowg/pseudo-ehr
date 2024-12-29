# app/controllers/medication_requests_controller.rb
class MedicationRequestsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/medication_requests
  def index
    @medication_requests = fetch_patient_medication_requests(params[:patient_id])
    flash.now[:notice] = 'No Medication request found' if @medication_requests.empty?
  rescue StandardError => e
    Rails.logger.error e
    flash.now[:danger] = e.message
    @medication_requests = []
  end

  private

  def fetch_patient_medication_requests(patient_id)
    Rails.cache.fetch(cache_key_for_patient_medication_requests(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_medication_requests = cached_resources_type('MedicationRequest')

      if fhir_medication_requests.blank?
        entries = fetch_medication_requests_by_patient(patient_id)
        fhir_medication_requests = entries.select { |entry| entry.resourceType == 'MedicationRequest' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_medication_requests.map { |entry| MedicationRequests.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Medication Request:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching or parsing patient's Medication Request. Check the log for detail."
    end
  end
end
