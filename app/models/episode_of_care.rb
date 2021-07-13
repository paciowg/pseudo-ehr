################################################################################
#
# eLTSS EpisodeOfCare Model
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

class EpisodeOfCare < Resource

  include ActiveModel::Model

  attr_reader :id, :status, :patient, :care_manager, :fhir_client, :period, :type, :managing_organization
  attr_accessor :fhir_queries

  def initialize(fhir_episodeOfCare, fhir_client)
    @fhir_client            = fhir_client
    @id                     = fhir_episodeOfCare.id
    @status                 = fhir_episodeOfCare.status
    @period                 = fhir_episodeOfCare.period
    @type                   = fhir_episodeOfCare.type
    @care_manager           = @fhir_client.read(nil, fhir_episodeOfCare.careManager.reference).resource
    @managing_organization  = @fhir_client.read(nil, fhir_episodeOfCare.managingOrganization.reference).resource
    @patient                = @fhir_client.read(nil, fhir_episodeOfCare.patient.reference).resource
  end

  #-----------------------------------------------------------------------------

  def encounters
    reassessment_timepoints.map { |timepoint| timepoint.part_of }.uniq!
  end
  
  #-----------------------------------------------------------------------------

  def reassessment_timepoints
    timepoints = []
    search_param =  { search: 
            { parameters: 
              { 
                "episodeOfCare": ["EpisodeOfCare", @id].join('/') 
              } 
            } 
        }
    fhir_response = @fhir_client.search(FHIR::Encounter, search_param)
    fhir_bundle = fhir_response.resource
    unless fhir_bundle.nil?
      fhir_bundle.entry.each do |encounter|
        timepoints <<  ReAssessmentTimepoint.new(encounter.resource, @fhir_client)
      end
            
    end
    # To display the fhir queries
    @fhir_queries = []
    @fhir_queries << "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"

    return timepoints
  end
        
end
