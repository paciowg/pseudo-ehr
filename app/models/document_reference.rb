# DocumentReference Model
class DocumentReference < Resource
  attr_reader :id, :fhir_resource, :status, :identifier, :type, :date, :full_date, :author, :context_period,
              :category, :encounter, :title, :contents, :patient_id, :patient

  def initialize(fhir_document_reference, bundle_entries = [])
    @id = fhir_document_reference.id
    @fhir_resource = fhir_document_reference
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = @fhir_resource.status
    @category = fhir_document_reference.category&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @type = coding_string(@fhir_resource.type&.coding)&.gsub('()', '').presence || '--'
    @identifier = read_identifier
    @date = parse_date(@fhir_resource.date).presence || '--'
    @full_date = @fhir_resource.date.presence || '--'
    @author = @fhir_resource.author&.map do |author|
                parse_provider_name(author, bundle_entries)
              end&.delete('--')&.join(', ').presence || '--'
    @contents = get_contents
    @title = @fhir_resource.description.presence || @fhir_resource.type&.text.presence ||
             contents.first&.title.presence || '--'

    self.class.update(self)
  end

  private

  def get_contents
    attachements = @fhir_resource.content.map(&:attachment)
    non_json_atchmts = attachements.select do |atchmt|
      type = atchmt.contentType
      type.present? && type != 'application/fhir+json' && type != 'application/json'
    end

    non_json_atchmts.map do |atchmt|
      ContentAttachment.new(
        title: atchmt.title || description, type: atchmt.contentType, data: atchmt.data,
        url: atchmt.url, creation_date: parse_date(atchmt.creation)
      )
    end
  end

  def read_identifier
    type.downcase.gsub(/[[:punct:]\s]/, '')
  end
end
