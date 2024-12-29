# app/controllers/document_references_controller.rb
class DocumentReferencesController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/document_reference
  def index
    @document_references = fetch_patient_document_reference(params[:patient_id])
    flash.now[:notice] = 'No Document Reference found' if @document_references.empty?
  rescue StandardError => e
    Rails.logger.error e
    flash.now[:danger] = e.message
    @document_references = []
  end

  private

  def fetch_patient_document_reference(patient_id)
    Rails.cache.fetch(cache_key_for_patient_document_references(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_document_references = cached_resources_type('DocumentReference')

      if fhir_document_references.blank?
        entries = fetch_document_references_by_patient(patient_id)
        fhir_document_references = entries.select { |entry| entry.resourceType == 'DocumentReference' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_document_references.map { |entry| DocumentReference.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Document References:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching or parsing patient's Document Reference. Check the log for detail."
    end
  end
end
