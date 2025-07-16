module Api
  # Controller for processing incoming QuestionnaireResponses and converting them
  # into PFE FHIR Observations, then posting the results to an external FHIR server.
  class QuestionnaireResponsesController < ApplicationController
    skip_before_action :current_server, raise: false

    def create
      if fhir_server_params.blank? || questionnaire_response_params.blank?
        return render json: {
          error: 'Missing required parameter(s): fhir_server, questionnaire_response'
        }, status: :bad_request
      end

      processor = QuestionnaireResponseProcessor.new(
        questionnaire_response_params,
        fhir_server: fhir_server_params
      )

      result = processor.call

      if result.success?
        head :created
      else
        render json: result.error.as_json, status: :unprocessable_entity
      end
    end

    private

    def questionnaire_response_params
      params.require(:questionnaire_response).permit!
    end

    def fhir_server_params
      params.require(:fhir_server).permit!
    end
  end
end
