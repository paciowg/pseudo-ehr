################################################################################
#
# DocumentReference Model
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class DocumentReference < Resource

  include ActiveModel::Model

  attr_reader :id, :text, :identifier, :status, :doc_status, :type, :category,
                :subject, :date, :author, :authenticator, :custodian, :relates_to,
                :description, :security_label, :content, :context

  #-----------------------------------------------------------------------------

  def initialize(fhir_document_ref)
    @id                   = fhir_document_ref.id
    @text                 = fhir_document_ref.text
    @identifier           = parse_identifiers(fhir_document_ref.identifier)
    @status               = fhir_document_ref.status
    @doc_status           = fhir_document_ref.docStatus
    @type                 = fhir_document_ref.type
    @category             = fhir_document_ref.category
    @subject              = fhir_document_ref.subject
    @date                 = fhir_document_ref.date.to_date
    @author               = fhir_document_ref.author
    @authenticator        = fhir_document_ref.authenticator
    @custodian            = fhir_document_ref.custodian
    @relates_to           = fhir_document_ref.relatesTo
    @description          = fhir_document_ref.description
    @security_label       = fhir_document_ref.securityLabel
    @content              = fhir_document_ref.content
    @context              = fhir_document_ref.context
  end

  #-----------------------------------------------------------------------------
  private
  #-----------------------------------------------------------------------------

  def parse_identifiers(identifiers)
    result = {}

    identifiers.each do |identifier|
      result[identifier.system] = identifier.value
    end

    result
  end

end