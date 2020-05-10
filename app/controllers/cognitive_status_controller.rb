################################################################################
#
# Cognitive Status Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class CognitiveStatusController < ApplicationController

	def index
		fhir_client = SessionHandler.fhir_client(session.id)
    fhir_patient = SessionHandler.fhir_client(session.id).read(FHIR::Patient, 
                            params['patient']).resource

    @patient = Patient.new(fhir_patient, fhir_client)
    @cognitive_statuses = @patient.all_cognitive_statuses
	end

  #-----------------------------------------------------------------------------

	def show
		fhir_client = SessionHandler.fhir_client(session.id)
    fhir_bundled_cognitive_status = fhir_client.read(
    																		FHIR::Observation, params[:id]).resource
		@bundled_cognitive_status = BundledCognitiveStatus.new(
                                  fhir_bundled_cognitive_status, fhir_client)
		@cognitive_statuses = @bundled_cognitive_status.cognitive_statuses
	end
	
end
