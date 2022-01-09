################################################################################
#
# SPLASCH Collections Controller
#
# 	SPLASCH = SPeech, LAnguage, Swallowing, cognitive Communication, and Hearing
#
# Copyright (c) 2022 The MITRE Corporation.  All rights reserved.
#
################################################################################

class SplaschCollectionsController < ApplicationController

	def index
		fhir_client = SessionHandler.fhir_client(session.id)
    fhir_patient = SessionHandler.fhir_client(session.id).read(FHIR::Patient, 
                            params['patient']).resource

    @patient = Patient.new(fhir_patient, fhir_client)
    @splasch_collections = @patient.all_splasch_collections
	end

  #-----------------------------------------------------------------------------

	def show
		fhir_client = SessionHandler.fhir_client(session.id)
    fhir_splasch_collection = fhir_client.read(
    																		FHIR::Observation, params[:id]).resource
		@splasch_collection = SplaschCollection.new(
                                  fhir_splasch_collection, fhir_client)
		@splasch_observations = @splasch_collection.splasch_observations
	end
	
end
