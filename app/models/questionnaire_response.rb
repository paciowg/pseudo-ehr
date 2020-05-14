################################################################################
#
# PACIO Questionnaire Response Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class QuestionnaireResponse < Resource

	include ActiveModel::Model

	attr_reader :id, :questionnaire, :status, :subject, 
				:item, :resourceType

  #-----------------------------------------------------------------------------

	def initialize(fhir_questionnaire_response)
		@id 									= fhir_questionnaire_response.id
		@resourceType							= fhir_questionnaire_response.resourceType
        @questionnaire                      = fhir_questionnaire_response.questionnaire
		@status 							= fhir_questionnaire_response.status
		@subject							= fhir_questionnaire_response.subject
        @item                           = fhir_questionnaire_response.item
	end
	
end
