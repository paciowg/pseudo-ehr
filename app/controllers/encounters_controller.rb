################################################################################
#
# Re-assessment Timepoint Encounters Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class EncountersController < ApplicationController
    
    before_action :set_fhir_client
    
    def index
        patient_id = params[:patient_id]
        redirect_to root_path && return if patient_id.blank?
        
        fhir_patient = @fhir_client.read(FHIR::Patient, patient_id).resource
        @patient = Patient.new(fhir_patient, @fhir_client)
        @encounters = @patient.encounters
        # byebug
    end
    
    def show
        fhir_response = @fhir_client.read(FHIR::Encounter, params[:id])
        fhir_encounter = fhir_response.resource
        @encounter = Encounter.new(fhir_encounter, @fhir_client) unless fhir_encounter.nil?
        @patient = Patient.new(@encounter.subject, @fhir_client)
        # byebug
        # Display the fhir query being run on the UI to help implementers
        @fhir_query = "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
    end
    
    private

    def set_fhir_client
        @fhir_client = SessionHandler.fhir_client(session.id)
    end
    
end