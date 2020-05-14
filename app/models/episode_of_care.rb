################################################################################
#
# eLTSS EpisodeOfCare Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class EpisodeOfCare < Resource
    include ActiveModel::Model

    attr_reader :id, :status, :patient, :careManager

    def initialize(fhir_episodeOfCare, fhir_client)
        @id = fhir_episodeOfCare.id
        @status = fhir_episodeOfCare.status
        @patient = fhir_episodeOfCare.patient
        @careManager = fhir_episodeOfCare.careManager
        
end
