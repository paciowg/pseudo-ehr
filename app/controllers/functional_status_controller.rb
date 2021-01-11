################################################################################
#
# Functional Status Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class FunctionalStatusController < ApplicationController

	def index
		fhir_client = SessionHandler.fhir_client(session.id)
    fhir_patient = SessionHandler.fhir_client(session.id).read(FHIR::Patient, 
    												params['patient']).resource

    @patient = Patient.new(fhir_patient, fhir_client)
    @functional_statuses = @patient.all_functional_statuses
	end

  #-----------------------------------------------------------------------------

	def show
		fhir_client = SessionHandler.fhir_client(session.id)
    fhir_bundled_functional_status = 
            fhir_client.read(FHIR::Observation, params[:id]).resource
            
		@bundled_functional_status = 
						BundledFunctionalStatus.new(fhir_bundled_functional_status, fhir_client)
		@functional_statuses = @bundled_functional_status.functional_statuses
	end

end
