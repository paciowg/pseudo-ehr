################################################################################
#
# Dashboard Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class DashboardController < ApplicationController

  def index
    patient_id = params[:patient]

    if patient_id.present?
      fhir_patient = SessionHandler.fhir_client(session.id).
                              read(FHIR::Patient, patient_id).resource

      @patient              = Patient.new(fhir_patient, SessionHandler.fhir_client(session.id))
      #@medications          = @patient.medications
      #@functional_statuses  = @patient.bundled_functional_statuses
      #@cognitive_statuses   = @patient.bundled_cognitive_statuses
      @splasch_observations = @patient.splasch_observations
      # @spoken_language_comprehension_observations = @patient.spoken_language_comprehension_observations
      # @spoken_language_expression_observations = @patient.spoken_language_expression_observations
      # @swallowing_observations = @patient.swallowing_observations
      #@splasch_collections  = @patient.splasch_collections
    else
      redirect_to :root
    end
  end

end
