################################################################################
#
# SPLASCH Collection Model
#
# Copyright (c) 2022 The MITRE Corporation.  All rights reserved.
#
################################################################################

class SplaschCollection < Resource

	include ActiveModel::Model

	attr_reader :id, :text, :based_on, :part_of, :status, :category, :code, 
								:subject, :focus, :encounter, :effective, :performer,
								:value_string, :data_absent_reason, :interpretation, :note,
								:body_site, :method, :specimen, :device, :reference_range,
								:has_member, :derived_from, :component 

  #-----------------------------------------------------------------------------

	def initialize(fhir_splasch_collection, fhir_client)
		@id 									= fhir_splasch_collection.id
		@text									= fhir_splasch_collection.text
		@based_on							= fhir_splasch_collection.basedOn
		@part_of							= fhir_splasch_collection.partOf
		@status 							= fhir_splasch_collection.status
		@category							= fhir_splasch_collection.category
		@code									= fhir_splasch_collection.code
		@subject							= fhir_splasch_collection.subject
		@focus								= fhir_splasch_collection.focus
		@encounter						= fhir_splasch_collection.encounter
		@effective						= DateTime.parse(fhir_splasch_collection.effective)
		@performer						= fhir_splasch_collection.performer
		@value_string					= fhir_splasch_collection.valueString
		@data_absent_reason		= fhir_splasch_collection.dataAbsentReason
		@interpretation				= fhir_splasch_collection.interpretation
		@note 								= fhir_splasch_collection.note
		@body_site						= fhir_splasch_collection.bodySite
		#@method								= fhir_splasch_collection.method
		@specimen							= fhir_splasch_collection.specimen
		@device								= fhir_splasch_collection.device
		@reference_range			= fhir_splasch_collection.referenceRange
		@has_member						= fhir_splasch_collection.hasMember
		@derived_from					= fhir_splasch_collection.derivedFrom
		@component						= fhir_splasch_collection.component

		@fhir_client					= fhir_client
	end
	
  #-----------------------------------------------------------------------------

  def splasch_observations
    splasch_observations = []
    self.has_member.each do |member|
      member_id = member.reference.split('/').last
      fhir_splasch_observation = @fhir_client.read(FHIR::Observation, member_id).resource

      splasch_observations << SplaschObservation.new(fhir_splasch_observation) unless
                                            fhir_splasch_observation.nil?
    end

    return splasch_observations
  end

end
