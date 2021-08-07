################################################################################
#
# Re-assessment Timepoint Encounters Controller
#
# Copyright (c) 2021 The MITRE Corporation.  All rights reserved.
#
################################################################################

class ReAssessmentTimepointsController < ApplicationController
    
    def new
        
    end

    def create
        
    end
    
    def show
        fhir_client = SessionHandler.fhir_client(session.id)
        fhir_response = fhir_client.read(FHIR::Encounter, params[:id])

        if fhir_response.resource
          @reassessment_timepoint = ReAssessmentTimepoint.new(fhir_response.resource, fhir_client)
          @patient = Patient.new(@reassessment_timepoint.subject, fhir_client)

          #Display the fhir query being run on the UI
          @fhir_queries = ["#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"] + @reassessment_timepoint.fhir_queries
        else
          redirect_to request.referer || root_path
        end
        
    end
    
end