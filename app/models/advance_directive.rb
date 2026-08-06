# AdvanceDirective Model
class AdvanceDirective < Resource
  attr_reader :id, :status, :doc_status, :type, :subject, :author, :date, :custodian, :description,
              :compositions, :relates_to_ref_id, :relates_to_code, :fhir_doc_ref,
              :version, :identifier, :doc_revoke_status, :contents, :patient_id

  def initialize(fhir_doc_ref, compositions)
    @fhir_doc_ref = fhir_doc_ref
    @id = fhir_doc_ref.id
    @status = fhir_doc_ref.status
    @doc_status = fhir_doc_ref.docStatus
    @doc_revoke_status = read_revoke_status_ext
    @type = coding_string(fhir_doc_ref.type&.coding)
    @subject = fhir_doc_ref.subject&.reference
    @patient_id = @subject&.split('/')&.last
    @author = fhir_doc_ref.author&.first&.display || '--'
    @date = read_doc_creation_date
    @custodian = compositions&.first&.custodian
    @description = fhir_doc_ref.description
    @compositions = compositions
    relates_to = fhir_doc_ref.relatesTo&.first
    @relates_to_ref_id = extract_resource_data(relates_to&.target)&.last
    @relates_to_code = relates_to&.code
    @version = read_version_extension
    @identifier = read_identifier
    @contents = get_contents

    self.class.update(self)
  end

  def read_revoke_status_ext
    revoke_ext = fhir_doc_ref.extension.find do |ext|
      ext.url == 'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/adi-document-revoke-status-extension'
    end
    return if revoke_ext.blank?

    revoke_ext.valueCoding.code
  end

  def revoked?
    doc_revoke_status == 'cancelled'
  end

  class << self
    def filter_by_status(status)
      all.filter { |r| r.status == status }
    end
  end

  private

  def get_contents
    # Contents can come from attachments from the DocumentReference or within the ADI Bundle pointed to by the
    # DocumentReference; in the latter case they may be contained resources in the ADI Composition
    # NOTE: this is an over simplification and there may be other options, e.g. as Binary references in the bundle
    attachments = @fhir_doc_ref.content.map(&:attachment)
    @compositions.each do |composition|
      composition.fhir_resource.contained.each do |contained|
        contained.content.each do |content|
          attachments << content.attachment if content.attachment
        end
      end
    end
    non_json_atchmts = attachments.select do |atchmt|
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

  def read_doc_creation_date
    doc_creation_date = fhir_doc_ref.content.map { |content| content.attachment.creation }.compact.first
    return '--' if doc_creation_date.blank?

    Date.parse(doc_creation_date)
  end

  def read_version_extension
    version_ext = @fhir_doc_ref.extension.find { |ext| ext.url == 'http://hl7.org/fhir/StructureDefinition/composition-clinicaldocument-versionNumber' }
    version_ext&.valueString
  end

  def read_identifier
    coding_string(@fhir_doc_ref.type&.coding).downcase.delete('[],().-:{}_;').split.join
  end
end
