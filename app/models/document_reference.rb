# DocumentReference Model
class DocumentReference < Resource
  attr_reader :id, :fhir_resource, :status, :identifier, :type, :date, :full_date, :author, :attachment_title,
              :attachment_content_type, :attachment_url, :attachment_format, :encounter, :context_period, :category,
              :pdf, :pdf_binary_id, :description, :code, :target

  def initialize(fhir_document_reference, bundle_entries, pdf, pdf_binary_id)
    @id = fhir_document_reference.id
    @fhir_resource = fhir_document_reference
    @pdf = pdf
    @pdf_binary_id = pdf_binary_id
    @status = @fhir_resource.status
    @identifier = @fhir_resource.identifier
    @category = fhir_document_reference.category&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @type = coding_string(@fhir_resource.type&.coding)&.gsub('()', '').presence || '--'
    @date = parse_date(@fhir_resource.date).presence || '--'
    @full_date = @fhir_resource.date.presence || '--'
    @author = @fhir_resource.author&.map do |each|
                parse_provider_name(each, bundle_entries)
              end&.join(', ').presence || '--'
    @attachment_content_type = @fhir_resource.content&.map(&:attachment)&.map(&:contentType)
                                             &.join(', ').presence || '--'
    @attachment_title = @fhir_resource.content&.map(&:attachment)&.map(&:title)&.join(', ').presence || '--'
    @attachment_url = @fhir_resource.content&.map(&:attachment)&.map(&:url)&.join(', ').presence || '--'
    @attachment_format = @fhir_resource.content&.map(&:format)&.join(', ').presence || '--'
    @encounter = @fhir_resource&.context&.encounter&.display&.gsub('_', ' ').presence || '--'
    @context_period = @fhir_resource&.context&.period.presence || '--'
    @description = @fhir_resource&.description
    @code = fhir_document_reference.relatesTo&.map { |c| c.code }&.join(', ').presence || '--'
    @target = @fhir_resource&.relatesTo&.map do |each|
      find_related_document_reference(each, bundle_entries)
    end&.join(', ').presence || '--'
  end

  def find_related_document_reference(doc_ref, bundle_entries)
    resource_type, resource_id = doc_ref.target.reference.split('/')
    return '--' if resource_type.nil? || resource_id.nil?

    related_documents = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }
    related_documents.description
  end
end
