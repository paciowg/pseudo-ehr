# app/controllers/document_references_controller.rb
class DocumentReferencesController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count
  before_action :set_document_reference, only: [:bundle]

  # GET /patients/:patient_id/document_reference
  def index
    @document_references = fetch_patient_document_reference(params[:patient_id])
    flash.now[:notice] = I18n.t('controllers.document_references.no_references') if @document_references.empty?
  rescue StandardError => e
    Rails.logger.error(e.backtrace.join("\n"))
    flash.now[:danger] = e.message
    @document_references = []
  end

  # GET /patients/:patient_id/document_references/:id/bundle
  def bundle
    @bundle_content = @document_reference.bundle_contents.find { |content| content.id == params[:content_id] }

    if @bundle_content.blank?
      @bundle_error = 'Unable to load the document.'
      return
    end

    matching_server = allowed_fhir_server_for(@bundle_content.url)

    if matching_server.blank?
      @bundle_error = 'Unable to load the document.'
      return
    end

    client = FhirClientService.new(fhir_server: matching_server).client
    response = client.read(nil, nil, @bundle_content.url)
    @bundle = response&.resource || response

    unless @bundle.is_a?(FHIR::Bundle)
      @bundle_error = 'Unable to load the document.'
      return
    end

    @composition_title = extract_composition_title(@bundle)
  rescue StandardError => e
    Rails.logger.error("Error loading DocumentReference bundle:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    @bundle_error = 'Unable to load the document.'
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

  def set_document_reference
    @document_reference = DocumentReference.find(params[:id])

    return if @document_reference.present?

    raise "Document Reference #{params[:id]} not found"
  end

  def allowed_fhir_server_for(url)
    FhirServer.all.find { |server| url.start_with?(server.base_url) }
  end

  def extract_composition_title(bundle)
    composition_entry = bundle.entry.to_a.find { |entry| entry.resource.is_a?(FHIR::Composition) }
    composition = composition_entry&.resource

    composition&.title.presence
  end
end
