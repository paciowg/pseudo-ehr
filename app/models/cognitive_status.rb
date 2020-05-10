################################################################################
#
# Cognitive Status Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class CognitiveStatus < Resource

	include ActiveModel::Model

	attr_reader :id, :text, :status, :code, :subject, :effective_datetime, :value

  #-----------------------------------------------------------------------------

	def initialize(fhir_cognitive_status)
		@id 									= fhir_cognitive_status.id
		@text									= fhir_cognitive_status.text
		@status 							= fhir_cognitive_status.status
		@code									= fhir_cognitive_status.code
		@subject							= fhir_cognitive_status.subject
		@effective_datetime		= DateTime.parse(fhir_cognitive_status.effectiveDateTime)
		@value								= fhir_cognitive_status.valueCodeableConcept
	end

end
