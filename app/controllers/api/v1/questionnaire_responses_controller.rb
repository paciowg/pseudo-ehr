################################################################################
#
# Questionnaire Responses Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

module Api
  module V1

    class QuestionnaireResponsesController < ActionController::API

      respond_to :json

      before_action :setup_fhir_client

      def create
        params.permit!

        @fhir_client.begin_transaction

        sdc_questionnaire_response = params

      	bundled_observation = FHIR::Observation.new
        @fhir_client.add_transaction_request('POST', nil, bundled_observation)

      	extract_data(sdc_questionnaire_response)

        reply = @fhir_client.end_transaction

        if reply.code >= 200 && reply.code < 400
          head :ok
        else
          head reply.code
        end
      end

      #-------------------------------------------------------------------------
      private
      #-------------------------------------------------------------------------

      def extract_data(fhir_questionnaire_response, items = nil)
        items = fhir_questionnaire_response if items.nil?

        items[:item].each do |item|
          if item[:item].present?
            extract_data(fhir_questionnaire_response, item)
          else
            extract_item(fhir_questionnaire_response, item)
          end
        end
      end

      #-------------------------------------------------------------------------

      def extract_item(fhir_questionnaire_response, item)
        if item[:answer].present?
          fhir_observation = FHIR::Observation.new

          fhir_observation.basedOn             = fhir_questionnaire_response[:basedOn]
          fhir_observation.partOf              = fhir_questionnaire_response[:partOf]
          fhir_observation.status              = 'final'
          fhir_observation.category            = 'survey'
          fhir_observation.subject             = fhir_questionnaire_response[:subject]
          fhir_observation.encounter           = fhir_questionnaire_response[:context]
          fhir_observation.effectiveDateTime   = fhir_questionnaire_response[:authored]
          fhir_observation.issued              = fhir_questionnaire_response[:authored]
          fhir_observation.performer           = fhir_questionnaire_response[:author]
          #fhir_bservation.derivedFrom         = fhir_questionnaire_response

          answer = item[:answer].first
          if answer[:valueCoding].present?
            fhir_observation.code = answer[:valueCoding][:code]
            if answer[:valueCoding][:display].present?
              fhir_observation.valueString   = answer[:valueCoding][:display]
            end
          else
            fhir_observation.valueBoolean    = answer[:valueBoolean]
            fhir_observation.valueDateTime   = answer[:valueDateTime]
            fhir_observation.valueTime       = answer[:valueTime]
            fhir_observation.valueInteger    = answer[:valueInteger]
            fhir_observation.valueString     = answer[:valueString]
          end
        
          @fhir_client.add_transaction_request('POST', nil, fhir_observation)
        end
      end

      #-------------------------------------------------------------------------

      def setup_fhir_client
        @fhir_client ||= FHIR::Client.new(HEALTH_DATA_MGR)
      end

    end

  end
end
