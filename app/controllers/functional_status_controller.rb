################################################################################
#
# Functional Status Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class FunctionalStatusController < ApplicationController
	before_action :set_fhir_client

	def index

		fhir_patient = @fhir_client.read(FHIR::Patient, params['patient']).resource

		@patient = Patient.new(fhir_patient, @fhir_client)
		@functional_statuses = @patient.all_functional_statuses
	end

  #-----------------------------------------------------------------------------

	def show
		fhir_response = @fhir_client.read(FHIR::Observation, params[:id])
    	fhir_bundled_functional_status = fhir_response.resource
            
		@bundled_functional_status = 
						BundledFunctionalStatus.new(fhir_bundled_functional_status, @fhir_client)
		@functional_statuses = @bundled_functional_status.functional_statuses

		# Display the fhir query being run on the UI to help implementers
        @fhir_query = "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
	end

	private

    def set_fhir_client
        @fhir_client = SessionHandler.fhir_client(session.id)
    end
end
