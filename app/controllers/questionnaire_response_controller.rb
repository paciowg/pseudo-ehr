class QuestionnaireResponseController < ApplicationController
  def index
  end

  def show
    fhir_client = SessionHandler.fhir_client(session.id)
    fhir_questionnaire_response = fhir_client.read(FHIR::QuestionnaireResponse, params[:id]).resource
    @questionnaire_response = QuestionnaireResponse.new(fhir_questionnaire_response) unless fhir_questionnaire_response.nil?

    fhir_questionnaire = fhir_client.read(FHIR::Questionnaire, @questionnaire_response.patient.reference.split('/').last).resource
    @patient              = Patient.new(fhir_patient, fhir_client) unless fhir_patient.nil?
  end
end
