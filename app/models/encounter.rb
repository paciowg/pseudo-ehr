################################################################################
#
# Re-assessment Time Point Encounter Model
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Encounter < Resource
    
    include ActiveModel::Model

    attr_reader :id, :identifier, :status, :status_history, :class, :class_history, :type, :service_type, :priority,
                :subject, :episode_of_care, :based_on, :participant, :appointment, :period, :length, :reason_code,
                :diagnosis, :hospitalization, :location, :service_provider, :part_of

    #-----------------------------------------------------------------------------

    def initialize(fhir_encounter, fhir_client)
        @id                  = fhir_encounter.id
        @identifier          = fhir_encounter.identifier&.first
        @status              = fhir_encounter.status
        @status_history      = fhir_encounter.statusHistory
        @class               = fhir_encounter.class
        @class_history       = fhir_encounter.classHistory
        @type                = fhir_encounter.type
        @service_type        = fhir_encounter.serviceType
        @priority            = fhir_encounter.priority
        @episode_of_care     = fhir_encounter.episodeOfCare  
        @based_on            = fhir_encounter.basedOn        
        @participant         = fhir_encounter.participant    
        @appointment         = fhir_encounter.appointment
        @period              = fhir_encounter.period
        @length              = fhir_encounter.length
        @reason_code         = fhir_encounter.reasonCode&.first&.coding&.first
        @diagnosis           = fhir_encounter.diagnosis      # condition resource, use, rank
        @hospitalization     = fhir_encounter.hospitalization
        @location            = fhir_encounter.location        # list of locations the patient has been to
        @service_provider    = fhir_encounter.serviceProvider
        @part_of             = fhir_encounter.partOf
        
        @fhir_client         = fhir_client
        @subject             = @fhir_client.read(nil, fhir_encounter.subject.reference).resource
    end
    
    #-----------------------------------------------------------------------------

    def observations
        assessments = []
        search_param = { search: { parameters: { encounter: "Encounter/#{@id }"} } }
        fhir_observations = @fhir_client.search(FHIR::Observation, search_param ).resource&.entry&.map(&:resource)

        unless fhir_observations.nil?
            fhir_observations.compact.each do |observation|
                assessments << Observation.new(observation)
            end    
        end

        return assessments
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

    def service_requests
        services = []
        if based_on
            based_on.compact.each do |request|
                fhir_service_request = @fhir_client.read(nil, request.reference).resource
                services << ServiceRequest.new(fhir_service_request) if fhir_service_request
            end
        end
        
        return services
    end
    
    #-----------------------------------------------------------------------------
    
    def providers
        participants = []
        
        @participant&.each do |participant|
            provider = {}
            provider[:role] = participant.type&.first&.text
            provider[:period] = participant.period
            provider[:name] = participant.individual&.display
            participants << provider
        end
        
        return participants.compact
    end
    
    #-----------------------------------------------------------------------------
end