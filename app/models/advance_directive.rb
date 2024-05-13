# frozen_string_literal: true

# AdvanceDirective Model
class AdvanceDirective < Resource
  attr_reader :id, :status, :doc_status, :type, :subject, :author, :date, :custodian, :description,
              :compositions, :pdf, :pdf_binary_id, :relates_to_ref_id, :relates_to_code, :fhir_doc_ref

  def initialize(fhir_doc_ref, compositions, pdf, pdf_binary_id)
    @id = fhir_doc_ref.id
    @status = fhir_doc_ref.status
    @doc_status = fhir_doc_ref.docStatus
    @type = coding_string(fhir_doc_ref.type&.coding)
    @subject = fhir_doc_ref.subject&.reference
    @author = fhir_doc_ref.author&.first&.display || '--'
    @date = fhir_doc_ref.date ? Date.parse(fhir_doc_ref.date) : '--'
    @custodian = compositions&.first&.custodian
    @description = fhir_doc_ref.description
    @compositions = compositions
    @pdf = pdf
    @pdf_binary_id = pdf_binary_id
    relates_to = fhir_doc_ref.relatesTo&.first
    @relates_to_ref_id = extract_resource_data(relates_to&.target)&.last
    @relates_to_code = relates_to&.code
    @fhir_doc_ref = fhir_doc_ref
  end
end
