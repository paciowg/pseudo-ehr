################################################################################
#
# Questionnaire Responses Controller
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

module Api
  module V1

    class QuestionnaireResponsesController < ActionController::API

      respond_to :json

      before_action :setup_fhir_client  # Make sure we're connected to the server

      #-------------------------------------------------------------------------

      def create
        # TODO - Need to eliminate this...
        params.permit!

        @sdc_questionnaire_response = params
  
        @fhir_client.begin_transaction

      	bundled_observation = init_base_observation(@sdc_questionnaire_response)
        bundled_observation.category = category('survey')
        bundled_observation.meta = meta('http://pacioproject.org/StructureDefinition/pacio-bfs') 

      	extract_node(@sdc_questionnaire_response, bundled_observation)
        @fhir_client.add_transaction_request('POST', nil, bundled_observation)

        reply = @fhir_client.end_transaction
        head(reply.code)
      end

      #-------------------------------------------------------------------------
      private
      #-------------------------------------------------------------------------

      def init_base_observation(fhir_questionnaire_response)
        fhir_observation = FHIR::Observation.new

        fhir_observation.id                  = unique_id
        fhir_observation.text                = text(fhir_questionnaire_response)
        fhir_observation.basedOn             = fhir_questionnaire_response[:basedOn]
        fhir_observation.partOf              = fhir_questionnaire_response[:partOf]
        fhir_observation.status              = 'final'
        fhir_observation.subject             = fhir_questionnaire_response[:subject]
        fhir_observation.encounter           = fhir_questionnaire_response[:context]
        fhir_observation.effectiveDateTime   = fhir_questionnaire_response[:authored]
        fhir_observation.issued              = fhir_questionnaire_response[:authored]
        fhir_observation.performer           = performer(fhir_questionnaire_response)
        fhir_observation.derivedFrom         = derived_from(@sdc_questionnaire_response[:id])

        fhir_observation
      end

      #-------------------------------------------------------------------------

      def extract_node(fhir_questionnaire_response, bundled_observation, items = nil)
        items = fhir_questionnaire_response if items.nil?

        items[:item].each do |item|
          if item[:item].present?
            node_observation = init_base_observation(item)
            node_observation.category = category('survey')
            node_observation.meta = meta('http://pacioproject.org/StructureDefinition/pacio-bfs') 

            bundled_observation.hasMember << reference(node_observation)

            extract_node(item, node_observation, item)

            @fhir_client.add_transaction_request('POST', nil, node_observation)
          else
            extract_leaf(item, bundled_observation, item)
          end
        end
      end

      #-------------------------------------------------------------------------

      def extract_leaf(fhir_questionnaire_response, bundled_observation, item)
        if item[:answer].present?
          fhir_observation = init_base_observation(fhir_questionnaire_response)
          fhir_observation.meta = meta('http://pacioproject.org/StructureDefinition/pacio-fs') 

          answer = item[:answer].first
          fhir_observation.code = FHIR::CodeableConcept.new
          if answer[:valueCoding].present?
            fhir_observation.code.coding    = answer[:valueCoding]
          else
            fhir_observation.valueBoolean   = answer[:valueBoolean]
            fhir_observation.valueDateTime  = answer[:valueDateTime]
            fhir_observation.valueTime      = answer[:valueTime]
            fhir_observation.valueInteger   = answer[:valueInteger]
            fhir_observation.valueString    = answer[:valueString]
          end

          @fhir_client.add_transaction_request('POST', nil, fhir_observation)
          bundled_observation.hasMember << reference(fhir_observation)
        end
      end

      #-------------------------------------------------------------------------

      def reference(resource)
        { 
          reference: "Observation/#{resource.id}" 
        }
      end

      #-------------------------------------------------------------------------

      def questionnaire_name(fhir_questionnaire_response)
        fhir_questionnaire_response[:questionnaire].split('/').last
      end

      #-------------------------------------------------------------------------

      def setup_fhir_client
        @fhir_client ||= FHIR::Client.new(HEALTH_DATA_MGR)
      end

      #-------------------------------------------------------------------------

      def unique_id
        Digest::SHA1.hexdigest([Time.now, rand].join)
      end

      #-------------------------------------------------------------------------

      def performer(fhir_questionnaire_response)
        if fhir_questionnaire_response[:author].present?
          performer = fhir_questionnaire_response[:author]
        else
          # This is a hack for the connectathon to account for Structured Data 
          # Capture data that does not provide the author of the response.  The 
          # performer is required by Observation-based resources, so we have to 
          # put something there.
          #
          # In real life, this is something that could/would be enforced by the 
          # software used to fill out the assessment.

          performer = [
            {
              reference: "Practitioner/Connectathon-Practitioner-DanielGranger"
            },
            {
              reference: "PractitionerRole/Connectathon-Role-RN"
            },
            {
              reference: "Organization/Connectathon-Org-02",
              display: "Organization"
            }
          ]
        end

        performer
      end

      #-------------------------------------------------------------------------

      def text(fhir_questionnaire_response)
        {
          status: "generated",
          div: fhir_questionnaire_response[:linkId] || 
                              questionnaire_name(fhir_questionnaire_response)
        }
      end

      #-------------------------------------------------------------------------

      def category(value)
        [
          {
            coding: [
              {
                system: "http://terminology.hl7.org/CodeSystem/observation-category",
                code: value
              }
            ]
          }
        ]
      end

      #-------------------------------------------------------------------------

      def meta(value)
        { 
          profile: [ value ] 
        }
      end

      #-------------------------------------------------------------------------

      def derived_from(value)
        [
          {
            reference: "QuestionnaireResponse/#{value}"
          }
        ]     
      end

    end

  end
end
