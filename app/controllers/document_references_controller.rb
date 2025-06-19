# app/controllers/document_references_controller.rb
class DocumentReferencesController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/document_reference
  def index
    @document_references = fetch_patient_document_reference(params[:patient_id])
    flash.now[:notice] = 'No Document Reference found' if @document_references.empty?
  rescue StandardError => e
    Rails.logger.error(e.backtrace.join("\n"))
    flash.now[:danger] = e.message
    @document_references = []
  end

  private

  def fetch_patient_document_reference(patient_id)
    drs = DocumentReference.filter_by_patient_id(patient_id)
    return sort_and_group_docs(drs) unless DocumentReference.expired? || drs.blank?

    entries = retrieve_current_patient_resources
    fhir_document_references = filter_non_adi_docs(cached_resources_type('DocumentReference'))

    if fhir_document_references.blank?
      Rails.logger.info('Document Refs not found in patient record cache, fetching directly')
      entries = fetch_document_references_by_patient(patient_id, 500, DocumentReference.updated_at)
      fhir_document_references = entries.select { |entry| entry.resourceType == 'DocumentReference' }
      fhir_document_references = filter_non_adi_docs(fhir_document_references)
    end

    fhir_document_references.each { |ref| DocumentReference.new(ref, entries) }

    drs = DocumentReference.filter_by_patient_id(patient_id)
    sort_and_group_docs(drs)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Document References:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Error fetching or parsing patient's Document Reference. Check the log for detail."
  end

  def sort_and_group_docs(docs)
    docs.sort_by(&:full_date).reverse.group_by(&:identifier)
  end
end
