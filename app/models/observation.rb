################################################################################
#
# eLTSS Observation Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Observation < Resource

  include ActiveModel::Model
  
  attr_reader :id, :status, :code, :subject, :text, :resourceType, :value

  def initialize(fhir_observation)
    @id             = fhir_observation.id
    @resourceType   = fhir_observation.resourceType
    @status         = fhir_observation.status
    @code           = fhir_observation.code
    @value          = fhir_observation.value
    @subject        = fhir_observation.subject
    @text           = fhir_observation.text
  end

end
