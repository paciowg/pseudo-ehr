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
    @author = get_authors(bundle_entries)
    @contents = get_contents
    @title = @fhir_resource.description.presence || @fhir_resource.type&.text.presence ||
             contents.first&.title.presence || '--'

    self.class.update(self)
  end

  def bundle_contents
    attachments = @fhir_resource.content.to_a.map(&:attachment)

    attachments.filter_map do |attachment|
      next unless bundle_attachment?(attachment)
      next unless allowed_bundle_url?(attachment.url)

      ContentAttachment.new(
        title: attachment.title || title,
        type: attachment.contentType,
        url: attachment.url,
        creation_date: parse_date(attachment.creation)
      )
    end
  end

  private

  def get_authors(bundle_entries)
    author = @fhir_resource.author&.map do |author|
      parse_provider_name(author, bundle_entries)
    end
    author&.delete('--')

    author&.uniq&.compact&.join(', ').presence || '--'
  end

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

  def bundle_attachment?(attachment)
    attachment.contentType.in?(%w[application/fhir+json application/json]) &&
      attachment.url.present? &&
      attachment.url.include?('/Bundle/')
  end

  def allowed_bundle_url?(url)
    self.class.allowed_server_prefixes.any? { |server| url.start_with?(server) }
  end

  class << self
    def allowed_server_prefixes
      FhirServer.pluck(:base_url).compact
    end
  end
end
