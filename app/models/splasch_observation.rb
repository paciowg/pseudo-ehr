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
									

	SPEECH_COMPREHENSION = {
		"understand-simple-routine-low-demand": {
			display: "Understand simple messages in routine low demand situations",
			definition: "How often does the individual understand simple messages/conversations related to routine daily activities in LOW demand situations (e.g., following simple directions)?"
		},
		"understand-complex-low-demand": {
			display: "Understand complex messages in low demand situations",
			definition: "How often does the individual understand complex messages, as expected for chronological age, in LOW demand situations (e.g., story/lecture, sequencing of events, drawing appropriate conclusions, inferences, humor, subtle references)?"
		},
		"understand-simple-routine-high-demand": {
			display: "Understand simple messages in routine high demand situations",
			definition: "How often does the individual understand simple messages/conversations related to routine daily activities in HIGH demand situations (e.g., following simple directions)?"
		},
		"understand-complex-high-demand": {
			display: "Understand complex messages in high demand situations",
			definition: "How often does the individual understand complex messages, as expected for chronological age, in HIGH demand situations (e.g., story/lecture, sequencing of events, drawing appropriate conclusions, inferences, humor, subtle references)?"
		},
		"function-comprehension-without-assistance": {
			display: "Function without assistance due to comprehension deficit",
			definition: "How often does the individual function safely WITHOUT additional supervision/assistance (in excess of chronological age expectations) due to comprehension deficits?",
		},
		"communicate-without-assistance": {
			display: "Participate in communication without assistance",
			definition: "How often does the individual participate in communication exchanges WITHOUT additional assistance from communication partner (no more than would be expected for chronological age)?",
		}
	}

	SPEECH_EXPRESSION = {
		"exhibit-distracting-expression-difficulties": {
			display: "Expression of distracting spoken language expression difficulties",
			definition: "How often does the individual exhibit spoken language expression difficulties that are noticeable or distracting to the listener? Note: consider message content, form, pauses, extra time."
		},
		"simple-meaningful-word-expression": {
			display: "Expression of simple meaningful word or phrases",
			definition: "How often does the individual produce simple spoken word and phrases that are meaningful?"
		},
		"verbal-form-low-demand": {
			display: "Produce verbal messages with appropriate form in low demand situations",
			definition: "How often does the individual produce verbal messages with appropriate FORM in LOW demand situations? Note: consider phonology, morphology and syntax when assessing functional level."
		},
		"verbal-content-low-demand": {
			display: "Produce verbal messages with appropriate content in low demand situations",
			definition: "How often does the individual produce verbal messages with appropriate CONTENT in LOW demand situations? Note: consider semantic meaning when assessing functional level."
		},
		"verbal-form-high-demand": {
			display: "Produce verbal messages with appropriate form in high demand situations",
			definition: "How often does the individual produce verbal messages with appropriate FORM in HIGH demand situations (e.g., academic or work-related tasks)? Note: consider phonology, morphology and syntax when assessing functional level."
		},
		"verbal-content-high-demand": {
			display: "Produce verbal messages with appropriate content in high demand situations",
			definition: "How often does the individual produce verbal messages with appropriate CONTENT in HIGH demand situations (e.g., academic or work-related tasks)? Note: consider semantic meaning when assessing functional level."
		},
		"communicate-without-assistance": {
			display: "Participate in communication without assistance",
			definition: "How often does the individual participate in communication exchanges WITHOUT additional assistance from communication partner (no more than would be expected for chronological age)?"
		}
	}

	SWALLOWING = {
		"modified-solid-diet": {
			display: "Recommended modified solids diet",
			definition: "What modified diet is recommended for the individual to swallow solids safely?"
		},
		"modified-liquid-diet": {
			display: "Recommended modified liquids diet",
			definition: "What modified liquid is recommended for the individual to swallow safely?"
		},
		"non-oral-diet-sustenance": {
			display: "Nutrition and hydration diet delivered through non-oral means",
			definition: "What percentage of the individual's daily diet is delivered through non-oral means in order to maintain adequate nutrition and hydration?"
		},
		"oral-containment-secretion-difficulty": {
			display: "Difficulties with oral containment or secretion management",
			definition: "How often does the individual exhibit difficulties with oral containment or secretion management?"
		},
		"assistance-swallowing-safety": {
			display: "Require assistance or supervision for swallowing safety",
			definition: "How often does the individual require supervision/assistance at meal time due to swallowing safety (e.g., risk of aspiration, pocketing)? Note: If individual is NPO, rate supervision/assistance as 91-100% of the time."
		}
	}

	CATEGORIES = { 
		"spoken-language-comprehension": {
			text: "Spoken language comprehension", 
			system: "http://hl7.org/fhir/us/pacio-splasch/CodeSystem/SPLASCHSpeechComprehensionObservationCS",
			codes: SPEECH_COMPREHENSION 
		},
		"spoken-language-expression": { 
			text: "Spoken language expression", 
			system: "http://hl7.org/fhir/us/pacio-splasch/CodeSystem/SPLASCHSpeechExpressionObservationCS",
			codes: SPEECH_EXPRESSION 
		},
		"swallowing": {
			text: "Swallowing",
			system: "http://hl7.org/fhir/us/pacio-splasch/CodeSystem/SPLASCHSwallowingObservationCS",
			codes: SWALLOWING
		}
	}

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
		@value								= observation_value(fhir_splasch_observation)
	end

	def observation_value(fhir_splasch_observation)
		unless fhir_splasch_observation.valueCodeableConcept.nil?
			return fhir_splasch_observation.valueCodeableConcept.coding[0].display
		end
		# unless fhir_splasch_observation.valueString.nil?
		# 	return fhir_splasch_observation.valueString
		# end
		# unless fhir_splasch_observation.valueQuantity.nil?
		# 	return fhir_splasch_observation.valueQuantity.value.to_s + ( fhir_splasch_observation.valueQuantity.unit.nil? ? "" : fhir_splasch_observation.valueQuantity.unit )
		# end
		return nil
	end

	def is_splasch_observation()
		@code.coding.each do |coding|
			splasch_category = CATEGORIES.select {|category_name, category| category[:system] == coding.system}
			if splasch_category.empty?
				return false
			end
			puts splasch_category
			splasch_code = splasch_category.values[0][:codes].select {|code_name, code| code[:display] == coding.display}
			if splasch_code.empty?
				return false
			end
		end
		return true
	end
end
