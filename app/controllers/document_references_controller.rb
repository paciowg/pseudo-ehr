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
      fhir_document_references = filter_non_adi_docs(cached_resources_type('DocumentReference'))

      if fhir_document_references.blank?
        entries = fetch_document_references_by_patient(patient_id)
        fhir_document_references = entries.select { |entry| entry.resourceType == 'DocumentReference' }
        fhir_document_references = filter_non_adi_docs(fhir_document_references)
      end

      drs = fhir_document_references.map do |ref|
        DocumentReference.new(ref, entries)
      end

      drs.sort_by(&:full_date).reverse.group_by(&:identifier)
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Document References:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching or parsing patient's Document Reference. Check the log for detail."
    end
  end

  def check_content_attachment_resource(content)
    case content.attachment.contentType
    when 'application/pdf'
      'pdf'
    when 'application/fhir+json', 'application/json'
      return 'bundle' if content.attachment&.url&.include?('Bundle')

      'binary' if content.attachment&.url&.include?('Binary')
    end
  end

  def extract_id_from_ref(ref)
    ref&.split('/')&.last
  end

  def retrieve_bundle_from_binary(binary_id, content_type)
    begin
      fhir_binary = find_cached_resource('Binary', binary_id) || fetch_binary(binary_id)
      data = fhir_binary&.data

      return { pdf: data, pdf_binary_id: binary_id } if content_type == 'pdf'
    rescue StandardError => e
      Rails.logger.error "Failed to fetch ADI FHIR Binary:\n #{e.message.inspect}"
      return { pdf: nil, pdf_binary_id: binary_id } if content_type == 'pdf'
    end

    return if data.nil?

    fhir_attachment_json = JSON(Base64.decode64(data))
    fhir_attachment_bundle = FHIR::Bundle.new(fhir_attachment_json)
    fhir_attachment_bundle.entry.map(&:resource)
  rescue StandardError => e
    Rails.logger.error e.message.inspect
  end
end
