################################################################################
#
# Encounter Model
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class Encounter < Resource
    
    include ActiveModel::Model

    attr_reader :id, :status, :category, :type, :subject, :episode_of_care, :based_on, :participant, :period,
                :conditions, :hospitalization, :location, :service_provider

    #-----------------------------------------------------------------------------

    def initialize(fhir_encounter, fhir_client)
        @fhir_client         = fhir_client
        @id                  = fhir_encounter.id
        @status              = fhir_encounter.status
        @category            = fhir_encounter.local_class
        @type                = fhir_encounter.type
        @episode_of_care     = fhir_encounter.episodeOfCare  
        @based_on            = fhir_encounter.basedOn        # reference clinicalImpression
        @participant         = fhir_encounter.participant
        @period              = fhir_encounter.period
        @conditions          = fhir_encounter.diagnosis      # condition resource, use, rank
        @hospitalization     = fhir_encounter.hospitalization
        @location            = fhir_encounter.location        # list of locations the patient has been to
        @service_provider    = @fhir_client.try(:read, nil, fhir_encounter.serviceProvider&.reference)&.resource&.name
        
       
        @subject             = @fhir_client.read(nil, fhir_encounter.subject.reference).resource
    end
    
    #-----------------------------------------------------------------------------

    def reassessment_timepoints
        timepoints = []
        search_param =  { search: 
            { parameters: 
              { 
                "part-of": ["Encounter", @id].join('/') 
              } 
            } 
          }
        fhir_bundle = @fhir_client.search(FHIR::Encounter, search_param).resource
        unless fhir_bundle.nil?
            fhir_bundle.entry.each do |encounter|
                timepoints <<  ReAssessmentTimepoint.new(encounter.resource, @fhir_client)
            end
            
        end

        return timepoints
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

    def diagnoses
        conditions = []
        
        @conditions.each do |condition|
            diagnosis = {}
            fhir_condition = @fhir_client.read(nil, condition.condition.reference).resource
            diagnosis[:condition] = Condition.new(fhir_condition)
            diagnosis[:use] = condition.use.coding.map {|code| "#{code.display} (#{code.code})"}.join(", ")

            conditions << diagnosis
        end
        
        return conditions
    end
    
    #-----------------------------------------------------------------------------
end