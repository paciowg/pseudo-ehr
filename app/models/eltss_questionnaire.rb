################################################################################
#
# eLTSS Questionnaire Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class EltssQuestionnaire < Resource

  include ActiveModel::Model

  attr_reader :id, :name, :status, :item

  def initialize(fhir_eltss_questionnaire)
    @id       = fhir_eltss_questionnaire.id
    @name     = fhir_eltss_questionnaire.name
    @status   = fhir_eltss_questionnaire.status
    @item     = fhir_eltss_questionnaire.item
  end

end
