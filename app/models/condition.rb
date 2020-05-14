################################################################################
#
# eLTSS Condition Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Condition < Resource
    include ActiveModel::Model

    attr_reader :id, :text, :clinicalStatus, :verificationStatus, :category,
                :code, :subject

     #-----------------------------------------------------------------------------

     def initialize(fhir_condition)
        @id = fhir_condition.id
        @text = fhir_condition.text
        @clinicalStatus = fhir_condition.clinicalStatus
        @verificationStatus = fhir_condition.verificationStatus
        @category = fhir_condition.category
        @code = fhir_condition.code
        @subject = fhir_condition.subject
        puts "CLINICAL STATUS"
        puts @clinicalStatus
     end
end
