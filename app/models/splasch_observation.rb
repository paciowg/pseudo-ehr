################################################################################
#
# SPLASCH Observation Model
#
# 	SPLASCH = SPeech, LAnguage, Swallowing, cognitive Communication, and Hearing
#
# Copyright (c) 2022 The MITRE Corporation.  All rights reserved.
#
################################################################################

class SplaschObservation < Resource

	include ActiveModel::Model

	attr_reader :id, :text, :div, :status, :code, :subject, :effective_datetime, :value

  #-----------------------------------------------------------------------------

	def initialize(fhir_splasch_observation)
		@id 									= fhir_splasch_observation.id
		@text									= fhir_splasch_observation.text
		@div 									= fhir_splasch_observation.text.div
		@status 							= fhir_splasch_observation.status
		@code									= fhir_splasch_observation.code
		@subject							= fhir_splasch_observation.subject
		@effective_datetime		= DateTime.parse(fhir_splasch_observation.effectiveDateTime)
		@value								= fhir_splasch_observation.valueCodeableConcept
	end

end
