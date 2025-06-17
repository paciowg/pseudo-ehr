# AdvanceDirective Model
class AdvanceDirective < Resource
  attr_reader :id, :status, :doc_status, :type, :subject, :author, :date, :custodian, :description,
              :compositions, :relates_to_ref_id, :relates_to_code, :fhir_doc_ref,
              :version, :identifier, :doc_revoke_status, :contents

  def initialize(fhir_doc_ref, compositions)
    @fhir_doc_ref = fhir_doc_ref
    @id = fhir_doc_ref.id
    @status = fhir_doc_ref.status
    @doc_status = fhir_doc_ref.docStatus
    @doc_revoke_status = read_revoke_status_ext
    @type = coding_string(fhir_doc_ref.type&.coding)
    @subject = fhir_doc_ref.subject&.reference
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

  private

  def get_contents
    attachements = @fhir_doc_ref.content.map(&:attachment)
    non_json_atchmts = attachements.select do |atchmt|
      type = atchmt.contentType
      type.present? && type != 'application/fhir+json' && type != 'application/json'
    end

    non_json_atchmts.map do |atchmt|
      Content.new(
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
    coding_string(@fhir_doc_ref.type&.coding).downcase.delete('[],().-:{}_;').split.join('')
  end
end
