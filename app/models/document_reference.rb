# DocumentReference Model
class DocumentReference < Resource
  attr_reader :id, :fhir_resource, :status, :identifier, :type, :date, :full_date, :author, :attachment_title,
              :attachment_content_type, :attachment_url, :attachment_format, :encounter, :context_period, :category

  def initialize(fhir_document_reference, bundle_entries)
    @id = fhir_document_reference.id
    @fhir_resource = fhir_document_reference
    @status = @fhir_resource.status
    @identifier = @fhir_resource.identifier
    @category = fhir_document_reference.category&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @type = coding_string(@fhir_resource.type&.coding)&.gsub('()', '').presence || '--'
    @date = parse_date(@fhir_resource.date).presence || '--'
    @full_date = @fhir_resource.date.presence || '--'
    @author = @fhir_resource.author&.map(&:reference)&.join(', ')&.split('/')&.last.presence || '--'
    # @author = @fhir_resource.author&.map(&:display)&.join(', ').presence || '--'
    @attachment_content_type = @fhir_resource.content&.map(&:attachment)&.map(&:contentType)
                                             &.join(', ').presence || '--'
    @attachment_title = @fhir_resource.content&.map(&:attachment)&.map(&:title)&.join(', ').presence || '--'
    @attachment_url = @fhir_resource.content&.map(&:attachment)&.map(&:url)&.join(', ').presence || '--'
    @attachment_format = @fhir_resource.content&.map(&:format)&.join(', ').presence || '--'
    @encounter = @fhir_resource&.context&.encounter&.display&.gsub('_', ' ').presence || '--'
    @context_period = @fhir_resource&.context&.period.presence || '--'
  end
end
