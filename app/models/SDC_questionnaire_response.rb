################################################################################
#
# SDCQuestionnaire Response Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class SDCQuestionnaireResponse < Resource

  include ActiveModel::Model

  attr_reader :id, :text, :contained, :extension, :modifier_extension, 
                :identifier, :based_on, :part_of, :questionnaire, :status,
                :subject, :encounter, :authored, :author, :source, :items

  #-----------------------------------------------------------------------------

  def initialize(fhir_questionnaire_response)
    @id                                 = fhir_questionnaire_response.id
    @text                               = fhir_questionnaire_response.text
    @contained                          = fhir_questionnaire_response.contained
    @extension                          = fhir_questionnaire_response.extension
    #@questionnaire_response_signature   = ???
    @modifier_extension                 = fhir_questionnaire_response.modifier_extension
    @identifier                         = fhir_questionnaire_response.identifier
    @based_on                           = fhir_questionnaire_response.basedOn
    @part_of                            = fhir_questionnaire_response.partOf
    @questionnaire                      = fhir_questionnaire_response.questionnaire
    @status                             = fhir_questionnaire_response.status
    @subject                            = fhir_questionnaire_response.subject
    @encounter                          = fhir_questionnaire_response.encounter
    @authored                           = fhir_questionnaire_response.authored
    @author                             = fhir_questionnaire_response.author
    @source                             = fhir_questionnaire_response.source
    @items                              = fhir_questionnaire_response.item
  end

  #-----------------------------------------------------------------------------

  def to_fhir
  end

  #-----------------------------------------------------------------------------

  def extract_data(items = nil)
    bundled_functional_status = []
    items = @items if items.nil?

    items.each do |item|
      if item.item.present?
        extract_data(item)
      else
        bundled_functional_status << extract_item(item)
      end
    end

    return bundled_functional_status
  end

  #-----------------------------------------------------------------------------

  def extract_item(item)
    functional_status = FunctionalStatus.new(
                            based_on:             @based_on, 
                            part_of:              @part_of,
                            status:               'final',
                            category:             'survey',
                            code:                 @questionnaire.code,
                            subject:              @subject,
                            encounter:            @context,
                            effective_date_time:  @authored, 
                            issued:               @authored,
                            performer:            @author,
                            derived_from:         @this
                        )

    functional_status.value     = item.answer.first[:valueCoding][:code]
    functional_status.display   = item.answer.first[:valueCoding][:display]

    return functional_status
  end

end
