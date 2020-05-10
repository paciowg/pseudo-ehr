################################################################################
#
# Bundled Cognitive Status Model
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class BundledCognitiveStatus < Resource

	include ActiveModel::Model

	attr_reader :id, :text, :based_on, :part_of, :status, :category, :code, 
								:subject, :focus, :encounter, :effective, :performer,
								:value_string, :data_absent_reason, :interpretation, :note,
								:body_site, :method, :specimen, :device, :reference_range,
								:has_member, :derived_from, :component 

  #-----------------------------------------------------------------------------

	def initialize(fhir_bundled_cognitive_status, fhir_client)
		@id 									= fhir_bundled_cognitive_status.id
		@text									= fhir_bundled_cognitive_status.text
		@based_on							= fhir_bundled_cognitive_status.basedOn
		@part_of							= fhir_bundled_cognitive_status.partOf
		@status 							= fhir_bundled_cognitive_status.status
		@category							= fhir_bundled_cognitive_status.category
		@code									= fhir_bundled_cognitive_status.code
		@subject							= fhir_bundled_cognitive_status.subject
		@focus								= fhir_bundled_cognitive_status.focus
		@encounter						= fhir_bundled_cognitive_status.encounter
		@effective						= DateTime.parse(fhir_bundled_cognitive_status.effective)
		@performer						= fhir_bundled_cognitive_status.performer
		@value_string					= fhir_bundled_cognitive_status.valueString
		@data_absent_reason		= fhir_bundled_cognitive_status.dataAbsentReason
		@interpretation				= fhir_bundled_cognitive_status.interpretation
		@note 								= fhir_bundled_cognitive_status.note
		@body_site						= fhir_bundled_cognitive_status.bodySite
		#@method								= fhir_bundled_cognitive_status.method
		@specimen							= fhir_bundled_cognitive_status.specimen
		@device								= fhir_bundled_cognitive_status.device
		@reference_range			= fhir_bundled_cognitive_status.referenceRange
		@has_member						= fhir_bundled_cognitive_status.hasMember
		@derived_from					= fhir_bundled_cognitive_status.derivedFrom
		@component						= fhir_bundled_cognitive_status.component

		@fhir_client					= fhir_client
	end
	
  #-----------------------------------------------------------------------------

  def cognitive_statuses
    cognitive_statuses = []
    self.has_member.each do |member|
      member_id = member.reference.split('/').last
      fhir_cognitive_status = @fhir_client.read(FHIR::Observation, member_id).resource

      cognitive_statuses << CognitiveStatus.new(fhir_cognitive_status) unless
                                            fhir_cognitive_status.nil?
    end

    return cognitive_statuses
  end

end
