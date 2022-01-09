################################################################################
#
# SPLASCH Observations Controller
#
# 	SPLASCH = SPeech, LAnguage, Swallowing, cognitive Communication, and Hearing
#
# Copyright (c) 2022 The MITRE Corporation.  All rights reserved.
#
################################################################################

class SplaschObservationsController < ApplicationController

	def show
		fhir_client = SessionHandler.fhir_client(session.id)
    fhir_observation = fhir_client.read(FHIR::Observation, params[:id]).resource
		@splasch_observation = SplaschObservation.new(fhir_observation)
	end
	
end
