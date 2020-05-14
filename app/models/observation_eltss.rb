################################################################################
#
# eLTSS Observation Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################


class ObservationEltss < Resource
    include ActiveModel::Model
    
    attr_reader :id, :status, :code, :subject, :text

    def initialize(fhir_observation_eLTSS)
        @id = fhir_observation_eLTSS.id
        @status = fhir_observation_eLTSS.status
        @code   = fhir_observation_eLTSS.code
        @subject = fhir_observation_eLTSS.subject
        @text = fhir_observation_eLTSS.text
    end
end
