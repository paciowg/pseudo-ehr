################################################################################
#
# eLTSS RiskAssessment Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class RiskAssessment < Resource
    include ActiveModel::Model
    
    attr_reader :id, :status, :subject, :mitigation, :resourceType, :prediction

    def initialize(fhir_riskAssessment)
        @id = fhir_riskAssessment.id
        @status = fhir_riskAssessment.status
        @subject = fhir_riskAssessment.subject
        @mitigation = fhir_riskAssessment.mitigation
        @resourceType = fhir_riskAssessment.resourceType
        @prediction = fhir_riskAssessment.prediction
    end
end
