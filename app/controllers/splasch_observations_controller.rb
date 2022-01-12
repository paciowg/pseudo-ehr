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

	before_action :get_fhir_client

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

	VALUES = { 
		"LA6270-8": "Never",
		"LA10066-1": "Rarely",
		"LA10082-8": "Sometimes",
		"LA10044-8": "Often",
		"LA9933-8": "Always",
		"0-25-percent": "0-25% of the time",
		"26-49-percent": "26-49% of the time",
		"50-75-percent": "50-75% of the time",
		"76-90-percent": "76-90% of the time",
		"91-100-percent": "91-100% of the time"
	}

	#-----------------------------------------------------------------------------

	def show
    fhir_observation = @fhir_client.read(FHIR::Observation, params[:id]).resource
		@splasch_observation = SplaschObservation.new(fhir_observation)
	end
	
	#-----------------------------------------------------------------------------

	def new
		@patient = params[:patient]
		@categories = CATEGORIES.map { |key, value| [ value[:text], key.to_s ] }

		# Build list of codes grouped by category
		@codes = CATEGORIES.map do |key, value| 
							 [ 
							 		key.to_s, 
							 		value[:codes].map do |code_key, code_value|
										[ code_value[:display], code_key.to_s ]
									end 
							 ]
		end

		@values = VALUES.map { |key, value| [ value, key.to_s ] }

		bundle = @fhir_client.search(FHIR::Practitioner).resource
		@practitioners = bundle.entry.map {|p| [ p.resource.name.first.text, p.resource.id ] }
	end

	#-----------------------------------------------------------------------------

	def create
		new_observation = params[:splasch_observation]

		fhir_observation = FHIR::Observation.new
		fhir_observation.status = "final"

		category = new_observation[:category].to_sym

		coding 																= FHIR::Coding.new
		coding.system													= "http://hl7.org/fhir/us/pacio-splasch/CodeSystem/SPLASCHObservationCategoryCS"
		coding.code 													= new_observation[:category]
		coding.display												= CATEGORIES[category][:text]
		codeable_concept 											= FHIR::CodeableConcept.new 
		codeable_concept.coding								= [ coding ]
		fhir_observation.category							= [ codeable_concept ]

		code = new_observation[:code].to_sym

		coding 																= FHIR::Coding.new 
		coding.system  												= CATEGORIES[category][:system]
		coding.code 													= new_observation[:code]
		coding.display 												= CATEGORIES[category][:codes][code][:display]
		fhir_observation.code 								= FHIR::CodeableConcept.new
		fhir_observation.code.coding					= [ coding ]

		value = new_observation[:value].to_sym

		observation_value											= FHIR::Coding.new
		observation_value.system 							= "http://hl7.org/fhir/us/pacio-splasch/CodeSystem/SPLASCHFrequencyCS"
		observation_value.code 								= new_observation[:value]
		observation_value.display							= VALUES[value]
		fhir_observation.valueCodeableConcept	= FHIR::CodeableConcept.new
		fhir_observation.valueCodeableConcept.coding = [ observation_value ]

		fhir_observation.effectiveDateTime 		= Time.now.strftime("%FT%T%:z")

		fhir_observation.subject 							= FHIR::Reference.new 
		fhir_observation.subject.reference 		= [ "Patient", Rails::Html::LinkSanitizer.new.sanitize(params[:patient]) ].join('/')

		fhir_observation.performer						= FHIR::Reference.new 
		fhir_observation.performer.reference 	= [ "Practitioner", Rails::Html::LinkSanitizer.new.sanitize(new_observation[:performer]) ].join('/')

		fhir_observation.text 								= FHIR::Narrative.new
		fhir_observation.text.status 					= "generated"
		fhir_observation.text.div 						= SplaschObservation::generate_narrative(fhir_observation)

		result = @fhir_client.create(fhir_observation)

    respond_to do |format|
      if result.response[:code] == "201"
	      format.html { redirect_to dashboard_path(patient: params[:patient]), 
      									success: "Observation was successfully created (ID=#{result.id})" }
        format.json { render :show, status: :created, 
        								location: "Observation/#{observation_id}" }
      else
    		format.html { redirect_to dashboard_path(patient: params[:patient]),
    										alert: 'Creating new observation failed' }
    		# format.html { redirect_to new_splasch_observation_path(patient: params[:patient]),
    		# 								alert: 'Creating new observation failed' }
        format.json { render json: 'Creating new observation failed', 
        								status: :unprocessable_entity }
      end
    end
	end

	#-----------------------------------------------------------------------------
	private
	#-----------------------------------------------------------------------------

	def get_fhir_client
		@fhir_client ||= SessionHandler.fhir_client(session.id)
	end

end
