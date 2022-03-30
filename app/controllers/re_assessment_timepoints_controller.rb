################################################################################
#
# Re-assessment Timepoint Encounters Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class ReAssessmentTimepointsController < ApplicationController
    
    def new
        @fhir_client = SessionHandler.fhir_client(session.id)
        encounter_id = params[:encounter_id]
   	    @reassessment_timepoint = ReAssessmentTimepoint.new(FHIR::Encounter.new, @fhir_client)
	    @encounter = Encounter.getById(@fhir_client, encounter_id)
	    @reassessment_timepoint.part_of = FHIR::Reference.new
        @reassessment_timepoint.part_of.id = encounter_id
	    @reassessment_timepoint.part_of.reference = "Encounter/#{encounter_id}"
        @reassessment_timepoint.service_provider = @encounter.reassessment_timepoints.first&.service_provider
        @patient = Patient.new(@encounter.subject, @fhir_client)
        @all_practitioners = @fhir_client.search(FHIR::Practitioner).resource.entry.collect{ |singleEntry| singleEntry.resource }
        # @all_practioner_roles = @fhir_client.search(FHIR::PractitionerRole).resource.entry.collect{ |singleEntry| singleEntry.resource }
    end

    def create
        puts "here!"
        puts params
        @fhir_client = SessionHandler.fhir_client(session.id)
        encounter_id = params[:re_assessment_timepoint][:encounter_id]
        @encounter = Encounter.getById(@fhir_client, encounter_id)
        @reassessment_timepoint = @encounter.reassessment_timepoints.last
        fhir_timepoint = timepoint_from_params(params)
        save(fhir_timepoint, @fhir_client)
        redirect_to "/re_assessment_timepoints/#{fhir_timepoint.id}"
    #     @reassessment_timepoint = ReAssessmentTimepoint.new(@reassessment_timepoint, @fhir_client)
    #     respond_to do |format|
    #         if @reassessment_timepoint.save
    #           format.html { redirect_to "/re_assessment_timepoints/#{@reassessment_timepoint.id}" }
    #           format.json { render :show, status: :created, location: @care_plan }
    #         else
    #   #        format.html { render :new }
    #           format.json { render json: @care_plan.errors, status: :unprocessable_entity }
    #         end
    #       end
    end
    
    def show
        @fhir_client = SessionHandler.fhir_client(session.id)
        fhir_response = @fhir_client.read(FHIR::Encounter, params[:id])
        @reassessment_timepoint = ReAssessmentTimepoint.new(fhir_response.resource, @fhir_client)
        @patient = Patient.new(@reassessment_timepoint.subject, @fhir_client)

        #Display the fhir query being run on the UI
        @fhir_queries = ["#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"] + @reassessment_timepoint.fhir_queries
    end

    def save(fhir_timepoint, fhir_client)
        fhir_client.create(fhir_timepoint)
    end
    

    def timepoint_from_params(params)
        @fhir_client = SessionHandler.fhir_client(session.id)
        encounter_id = params[:re_assessment_timepoint][:encounter_id]
        fhir_timepoint = @fhir_client.read(FHIR::Encounter, @reassessment_timepoint.id).resource
        fhir_timepoint.id = fhir_timepoint.id.next
        fhir_timepoint.type[0].coding[0].code = params[:type]
        fhir_timepoint.status = params[:status]
        fhir_timepoint.serviceType.coding[0].code = params[:service_type]
        fhir_timepoint.identifier[0].value = params[:identifier]
        # fhir_timepoint.reasonCode[0].code = params[:reason]
        fhir_timepoint.reasonReference = []
        fhir_timepoint.participant = [fhir_timepoint.participant[0]]
        fhir_timepoint.participant[0].individual.reference = params[:participant]
        fhir_timepoint.period.start = params[:period_start]
        fhir_timepoint.period.end = params[:period_end]
        # fhir_timepoint.participant[0].individual.reference = params[:participant]
        # @reassessment_timepoint
    end
end