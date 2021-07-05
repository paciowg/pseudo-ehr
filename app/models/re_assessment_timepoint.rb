################################################################################
#
# Re-assessment Time Point Encounter Model
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class ReAssessmentTimepoint < Resource
    include ActiveModel::Model

    attr_reader :id, :identifier, :status, :category, :type, :service_type,
                :subject, :episode_of_care, :based_on, :participant, :period, :reason_code,
                :reason_reference, :diagnosis, :hospitalization, :location, :service_provider, :part_of

    #-----------------------------------------------------------------------------

    def initialize(fhir_encounter, fhir_client)
        @fhir_client         = fhir_client
        @id                  = fhir_encounter.id
        @identifier          = fhir_encounter.identifier&.first
        @status              = fhir_encounter.status
        @category            = fhir_encounter.local_class
        @type                = fhir_encounter.type
        @service_type        = fhir_encounter.serviceType
        @episode_of_care     = fhir_encounter.episodeOfCare  
        @based_on            = fhir_encounter.basedOn        # reference clinicalImpression
        @participant         = fhir_encounter.participant
        @period              = fhir_encounter.period
        @reason_code         = fhir_encounter.reasonCode
        @reason_reference    = fhir_encounter.reasonReference
        @diagnosis           = fhir_encounter.diagnosis      # condition resource, use, rank
        @hospitalization     = fhir_encounter.hospitalization
        @location            = fhir_encounter.location        # list of locations the patient has been to
        @service_provider    = @fhir_client.read(nil, fhir_encounter.serviceProvider&.reference)&.resource
        @part_of             = @fhir_client.read(nil, fhir_encounter.partOf.reference).resource
        
        @subject             = @fhir_client.read(nil, fhir_encounter.subject.reference).resource
    end
    
    #-----------------------------------------------------------------------------

    def assessments
        observations = []
        @reason_reference.each do |reference|
            observation = @fhir_client.read(nil, reference.reference).resource
            observations << BundledFunctionalStatus.new(observation, @fhir_client)
        end
        
        return observations
    end
    
    #-----------------------------------------------------------------------------

    def episodes_of_care
        episodes = []
        if episode_of_care
            episode_of_care.compact.each do |episode|
                fhir_episode = @fhir_client.read(nil, episode.reference).resource
                episodes << EpisodeOfCare.new(fhir_episode, @fhir_client) if fhir_episode
            end
        end
        
        return episodes
    end
    
    #-----------------------------------------------------------------------------
    
    def providers
        participants = []
        
        @participant&.each do |participant|
            fhir_practitioner = @fhir_client.read(nil, participant.individual.reference).resource
            practitioner = Practitioner.new(fhir_practitioner)
            search_param = {search: {
                parameters: {
                    practitioner: participant.individual.reference 
                    }
                }
            }
            fhir_role = @fhir_client.search(FHIR::PractitionerRole, search_param).resource.entry.first.resource
            role = PractitionerRole.new(fhir_role)

            provider = {}
            provider[:role] = role
            provider[:individual] =  practitioner
            participants << provider
        end
        
        return participants.compact
    end
    
    #-----------------------------------------------------------------------------

    def locations
        @location.map do |location|
            @fhir_client.read(nil, location.location.reference).resource
        end
    end
    
    #-----------------------------------------------------------------------------
end