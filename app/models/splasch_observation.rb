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
	attr_accessor :categories, :text, :status, :code, :subject, :performers, 
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
		@performers						= fhir_splasch_observation.performer
		@effective_datetime		= DateTime.parse(fhir_splasch_observation.effectiveDateTime)
		@value								= fhir_splasch_observation.valueCodeableConcept
	end

	#-----------------------------------------------------------------------------

	NARRATIVE_HEADER = "<div xmlns='http://www.w3.org/1999/xhtml'>"\
							"<p><b>Generated Narrative</b></p>"\
							"<div style='display: inline-block; background-color: #d9e0e7; "\
							"padding: 6px; margin: 4px; border: 1px solid #8da1b4; "\
							"border-radius: 5px; line-height: 60%'>"

	NARRATIVE_FOOTER = "</div></div>"

	def self.generate_narrative(fhir_observation)
		# Narrative templates
		NARRATIVE_HEADER + 
			narrative_title(fhir_observation) +
			narrative_status(fhir_observation) + 
			narrative_category(fhir_observation) +
			narrative_code(fhir_observation) +
			narrative_subject(fhir_observation) +
			narrative_effective_datetime(fhir_observation) +
			narrative_performers(fhir_observation) +
			narrative_value(fhir_observation) + 
			NARRATIVE_FOOTER
	end

	#-----------------------------------------------------------------------------
	private
	#-----------------------------------------------------------------------------

	def self.narrative_title(fhir_observation)
		narrative = "<p style='margin-bottom: 0px'>SPLASCH Observation"
		narrative += " (#{fhir_observation.id})" if fhir_observation.id.present?
		narrative += "</p>"
	end

	#-----------------------------------------------------------------------------

	def self.narrative_status(fhir_observation)
		"<p><b>status</b>: #{fhir_observation.status}</p>"
	end

	#-----------------------------------------------------------------------------

	def self.narrative_category(fhir_observation)
		narrative = "<p><b>categories</b>: "

		fhir_observation.category.each do |category|
			codings = []

			category.coding.each do |coding|
				codings << "#{coding.display} "\
											"<span style='background: LightGoldenRodYellow; margin: 4px; "\
											"border: 1px solid khaki'> "\
											"(<a href='#{coding.system}'>SPLASCH Observation Category Codes</a>"\
											"##{coding.code})</span>"
			end

			narrative += codings.join(', ')
		end

		narrative += "</p>"
	end

	#-----------------------------------------------------------------------------

	def self.narrative_code(fhir_observation)
		narrative = "<p><b>code</b>: "

		codings = []
		fhir_observation.code.coding.each do |coding|
			codings << "#{coding.display} "\
								"<span style='background: LightGoldenRodYellow; "\
								"margin: 4px; border: 1px solid khaki'> "\
								"(<a href='#{coding.system}'>#{coding.system}</a>##{coding.code})</span>"
		end

		narrative += codings.join(', ') + "</p>"
	end

	#-----------------------------------------------------------------------------

	def self.narrative_subject(fhir_observation)
		"<p><b>subject</b>: <a href='#{fhir_observation.subject.reference}'>"\
						"#{fhir_observation.subject.reference}</a></p>"
	end

	#-----------------------------------------------------------------------------

	def self.narrative_effective_datetime(fhir_observation)
		"<p><b>effective</b>: #{fhir_observation.effectiveDateTime}</p>"
	end

	#-----------------------------------------------------------------------------

	def self.narrative_performers(fhir_observation)
		narrative = "<p><b>performer</b>: </p><ul>"

		fhir_observation.performer = [ fhir_observation.performer ] unless 
												fhir_observation.performer.kind_of?(Array)

		fhir_observation.performer.each do |performer|
			narrative += "<li><a href='#{performer.reference}'>#{performer.reference}</a></li>"
		end

		narrative += "</ul>"
	end

	#-----------------------------------------------------------------------------

	def self.narrative_value(fhir_observation)
		narrative = "<p><b>value</b>: "

		codings = []
		fhir_observation.value.coding.each do |coding|
			codings << "#{coding.display} "\
								"<span style='background: LightGoldenRodYellow; "\
								"margin: 4px; border: 1px solid khaki'> "\
								"(<a href='#{coding.system}'>#{coding.system}</a>##{coding.code})</span>"
		end

		narrative += codings.join(', ') + "</p>"
	end

end
