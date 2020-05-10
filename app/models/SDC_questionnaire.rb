################################################################################
#
# Questionnaire Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class SDCQuestionnaire < Resource

  include ActiveModel::Model

  attr_reader :id, :text, :contained, :extension, :design_note, 
                :preferred_terminology_server, :modifer_extension, :url,
                :identifier, :version, :name, :title, :derived_from, :status,
                :experimental, :subject_type, :date, :publisher, :contact,
                :description, :use_context, :jurisdiction, :purpose, :copyright,
                :approval_date, :last_review_date, :effective_period, :code,
                :item, :questionnaire_responses

  #-----------------------------------------------------------------------------

  def initialize(fhir_questionnaire)
    @id                             = fhir_questionnaire.id
    @text                           = fhir_questionnaire.text
    @contained                      = fhir_questionnaire.contained
    @extension                      = fhir_questionnaire.extension
    @design_note                    = fhir_questionnaire.designNote
    #@preferred_terminology_server   = questionnaire.???
    @modifier_extension             = fhir_questionnaire.modifierExtension
    @url                            = fhir_questionnaire.url
    @identifier                     = fhir_questionnaire.identifier
    @version                        = fhir_questionnaire.version
    @name                           = fhir_questionnaire.name
    @title                          = fhir_questionnaire.title
    @derived_from                   = fhir_questionnaire.derivedFrom
    @status                         = fhir_questionnaire.status
    @experimental                   = fhir_questionnaire.experimental
    @subject_type                   = fhir_questionnaire.subjectType
    @date                           = fhir_questionnaire.date.to_date
    @publisher                      = fhir_questionnaire.publisher
    @contact                        = fhir_questionnaire.contact
    @description                    = fhir_questionnaire.description
    @use_context                    = fhir_questionnaire.useContext
    @jurisdiction                   = fhir_questionnaire.jurisdiction
    @purpose                        = fhir_questionnaire.purpose
    @copyright                      = fhir_questionnaire.copyright
    @approval_date                  = fhir_questionnaire.approvalDate.to_date
    @last_review_date               = fhir_questionnaire.lastReviewDate.to_date
    @effective_period               = fhir_questionnaire.effectivePeriod
    @code                           = fhir_questionnaire.code
    @item                           = fhir_questionnaire.item
  end

  #-----------------------------------------------------------------------------

  def questionnaire_responses
  end

end
