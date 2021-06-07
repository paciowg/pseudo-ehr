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
      if !Rails.cache.read("$document_bundle").nil?
        bundle = FHIR.from_contents(Rails.cache.read("$document_bundle"))
        fhir_patient = get_object_from_bundle('Patient/' + patient_id, bundle)
      end
      if fhir_patient.nil?
        fhir_patient = SessionHandler.fhir_client(session.id).
                                read(FHIR::Patient, patient_id).resource
      end
      @patient              = Patient.new(fhir_patient, SessionHandler.fhir_client(session.id))
      @medications          = @patient.medications
      @functional_statuses  = @patient.bundled_functional_statuses
      @cognitive_statuses   = @patient.bundled_cognitive_statuses
      @compositions         = @patient.compositions
      #byebug
    else
      redirect_to :root
    end
  end

  def get_object_from_bundle(fhir_reference, fhir_bundle)
    referenced_object = fhir_bundle.entry.map(&:resource).select do |resource| 
      resource.resourceType == fhir_reference.split('/')[0]
      resource.id == fhir_reference.split('/')[1]
    end
    referenced_object[0]
  end

end
