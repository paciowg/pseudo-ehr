module Api
  # Controller for processing incoming an QuestionnaireResponse and converting it
  # into PFE FHIR Observations, then posting the results to an external FHIR server.
  class QuestionnaireResponseProcessingController < ApplicationController
    skip_before_action :current_server, raise: false
    skip_before_action :verify_authenticity_token
    before_action :validate_params, only: [:convert_qr_to_pfe_and_submit]

    def convert_qr_to_pfe_and_submit
      fhir_server = params[:fhir_server]
      qr_hash = questionnaire_response_params.to_h

      processor = QuestionnaireResponseProcessor.new(
        qr_hash,
        fhir_server:
      )

      result = processor.call

      if result.success?
        render json: result.to_json, status: :ok
      else
        render json: result.to_json, status: :unprocessable_entity
      end
    end

    private

    def questionnaire_response_params
      params.require(:questionnaire_response).permit!
    end

    # Ensure the fhir_server param is present and is a url string
    # and that the questionnaire_response param is present and is a hash and is a QuestionnaireResponse
    def validate_params
      if params[:fhir_server].blank? || !params[:fhir_server].is_a?(String)
        render json: { error: 'Missing or invalid fhir_server parameter. Expecing a String URL' },
               status: :bad_request and return
      end

      if questionnaire_response_params.blank? || !questionnaire_response_params.is_a?(ActionController::Parameters)
        render json: {
                 error: 'Missing or invalid questionnaire_response parameter.
                 Expecting a FHIR QuestionnaireResponse resource'
               },
               status: :bad_request and return
      end

      return if questionnaire_response_params[:resourceType] == 'QuestionnaireResponse'

      render json: { error: 'Invalid resourceType in questionnaire_response parameter' }, status: :bad_request
    end
  end
end
