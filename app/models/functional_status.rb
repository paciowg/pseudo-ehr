################################################################################
#
# Functional Status Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class FunctionalStatus < Resource

	include ActiveModel::Model

	attr_reader :id, :text, :status, :code, :subject, :effective_datetime, :value

  #-----------------------------------------------------------------------------

	def initialize(fhir_functional_status)
		@id 									= fhir_functional_status.id
		@text									= fhir_functional_status.text
		@status 							= fhir_functional_status.status
		@code									= fhir_functional_status.code
		@subject							= fhir_functional_status.subject
		@effective_datetime		= DateTime.parse(fhir_functional_status.effectiveDateTime)
		@value								= fhir_functional_status.valueCodeableConcept
	end

end
