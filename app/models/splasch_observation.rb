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

	attr_reader		:id, :div
	attr_accessor :categories, :text, :status, :code, :subject, :performer, 
									:effective_datetime, :value

  #-----------------------------------------------------------------------------

	def initialize(fhir_splasch_observation)
		@id 									= fhir_splasch_observation.id
		@text									= fhir_splasch_observation.text
		if @text.present?
			@div 								= fhir_splasch_observation.text.div
		end
		@status 							= fhir_splasch_observation.status
		@categories						= fhir_splasch_observation.category
		@code									= fhir_splasch_observation.code
		@subject							= fhir_splasch_observation.subject
		@performer						= fhir_splasch_observation.performer
		@effective_datetime		= DateTime.parse(fhir_splasch_observation.effectiveDateTime) unless fhir_splasch_observation.effectiveDateTime.nil?
		@value								= fhir_splasch_observation.valueCodeableConcept
	end

end
