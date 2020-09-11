################################################################################
#
# Questionnaire Responses Controller
#
# Copyright (c) 2020 The MITRE Corporation.  All rights reserved.
#
################################################################################

require 'json'

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
        parse_questionnaire(@sdc_questionnaire_response[:questionnaire])

        @fhir_client.begin_transaction

        # Write the original questionnaire response and extract data into PACIO
        # resources
        questionnaire_response = FHIR::QuestionnaireResponse.new(@sdc_questionnaire_response)

        @fhir_client.add_transaction_request('PUT', nil, questionnaire_response)
        extract_data_from_questionnaire_response
        reply = @fhir_client.end_transaction

        head(reply.code)
      end

      #-------------------------------------------------------------------------
      private
      #-------------------------------------------------------------------------

      def parse_questionnaire(url)
        @questions = {}

        response = RestClient.get(url)
        questionnaire = JSON.parse(response.body)

        parse_questionnaire_node(questionnaire["item"])
      end

      #-------------------------------------------------------------------------

      def parse_questionnaire_node(items)
        items.each do |item|
          if item["item"].present?
            parse_questionnaire_node(item["item"])
          else
            parse_questionnaire_leaf(item)
          end
        end
      end

      #-------------------------------------------------------------------------

      def parse_questionnaire_leaf(item)
        @questions[item["linkId"]] = item["code"]
      end

      #-------------------------------------------------------------------------

      def extract_data_from_questionnaire_response
        bundled_observation = init_base_observation(@sdc_questionnaire_response)
        bundled_observation.category = category('survey')
        bundled_observation.meta = meta('https://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bfs') 

        extract_node(@sdc_questionnaire_response, bundled_observation)
        #@fhir_client.add_transaction_request('PUT', nil, bundled_observation)
      end

      #-------------------------------------------------------------------------

      def extract_node(fhir_questionnaire_response, bundled_observation, items = nil)
        items = fhir_questionnaire_response if items.nil?

        if items[:item].present?
          items[:item].each do |item|
            if item[:item].present?
              puts 'item[:linkId]...'
              node_observation = init_base_observation(item)
              node_observation.meta = node_meta(item)

              bundled_observation.hasMember << reference(node_observation)

              # TODO - Temporarily limit data we're converting
              extract_node(item, node_observation, item)
              if filter(item)
                puts 'yes'
                @fhir_client.add_transaction_request('PUT', nil, node_observation)
              end
           else
              extract_leaf(item, bundled_observation, item)
            end
          end
        end
      end

      #-------------------------------------------------------------------------

      def extract_leaf(fhir_questionnaire_response, bundled_observation, item)
        if item[:answer].present?
          fhir_observation = init_base_observation(fhir_questionnaire_response)
          fhir_observation.meta = leaf_meta(bundled_observation) 

          # TODO - Add multiple answer support
          answer = item[:answer].first
          if answer[:valueCoding].present?
            fhir_observation.valueCodeableConcept = FHIR::CodeableConcept.new
            fhir_observation.valueCodeableConcept.coding = [ answer[:valueCoding] ]
          else
            fhir_observation.valueBoolean   = answer[:valueBoolean]
            fhir_observation.valueDateTime  = answer[:valueDateTime]
            fhir_observation.valueTime      = answer[:valueTime]
            fhir_observation.valueInteger   = answer[:valueInteger]
            fhir_observation.valueString    = answer[:valueString]
          end

          @fhir_client.add_transaction_request('PUT', nil, fhir_observation)
          bundled_observation.hasMember << reference(fhir_observation)
        end
      end

      #-------------------------------------------------------------------------

      def init_base_observation(fhir_questionnaire_response)
        fhir_observation = FHIR::Observation.new

        fhir_observation.id                  = unique_id
        fhir_observation.text                = text(fhir_questionnaire_response)
        fhir_observation.basedOn             = @sdc_questionnaire_response[:basedOn]
        fhir_observation.partOf              = @sdc_questionnaire_response[:partOf]
        fhir_observation.code                = question_coding(fhir_questionnaire_response)
        fhir_observation.status              = 'final'
        fhir_observation.category            = category('survey')
        fhir_observation.subject             = @sdc_questionnaire_response[:subject]
        fhir_observation.encounter           = @sdc_questionnaire_response[:context]
        fhir_observation.effectiveDateTime   = @sdc_questionnaire_response[:authored]
        fhir_observation.issued              = @sdc_questionnaire_response[:authored]
        fhir_observation.performer           = performer(@sdc_questionnaire_response)
        fhir_observation.derivedFrom         = derived_from(@sdc_questionnaire_response[:id])

        fhir_observation
      end

      #-------------------------------------------------------------------------

      def reference(resource)
        { 
          reference: "Observation/#{resource.id}" 
        }
      end

      #-------------------------------------------------------------------------

      def questionnaire_name(fhir_questionnaire_response)
        fhir_questionnaire_response[:questionnaire]#.split('/').last
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
        # else
        #   # This is a hack for the connectathon to account for Structured Data 
        #   # Capture data that does not provide the author of the response.  The 
        #   # performer is required by Observation-based resources, so we have to 
        #   # put something there.
        #   #
        #   # In real life, this is something that could/would be enforced by the 
        #   # software used to fill out the assessment.

        #   if @sdc_questionnaire_response[:authored] == "2020-04-08T19:57:19+00:00"
        #     performer = [
        #       {
        #         reference: "Practitioner/Connectathon-Practitioner-RonMarble"
        #       },
        #       {
        #         reference: "PractitionerRole/Connectathon-Role-PT"
        #       },
        #       {
        #         reference: "Organization/Connectathon-Org-01",
        #         display: "Organization"
        #       }
        #     ]
        #   else
        #     performer = [
        #       {
        #         reference: "Practitioner/Connectathon-Practitioner-DanielGranger"
        #       },
        #       {
        #         reference: "PractitionerRole/Connectathon-Role-RN"
        #       },
        #       {
        #         reference: "Organization/Connectathon-Org-02",
        #         display: "Organization"
        #       }
        #     ]
        #   end
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

      def node_meta(item)
        meta(META_MAPPING[item[:linkId]] || 
                    "https://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bfs")
      end

      #-------------------------------------------------------------------------

      def leaf_meta(bundled_observation)
        bundled_type = bundled_observation.meta[:profile].first
        if bundled_type.ends_with?('pacio-bfs')
          meta("https://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bfs")
        else
          meta("https://paciowg.github.io/cognitive-status-ig/StructureDefinition/pacio-bcs")
        end
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

      #-------------------------------------------------------------------------

      def question_coding(fhir_questionnaire_response)
        {
          coding: @questions[fhir_questionnaire_response[:linkId]] || 
                      [ CODE_MAPPING[fhir_questionnaire_response[:linkId]] ]
        }
      end

      #-------------------------------------------------------------------------

      def default_coding
        {
          system: "http://loinc.org",
          code: "87509-6",
          display: "Long-Term Care Hospital (LTCH) Continuity Assessment Record and Evaluation (CARE) Data Set (LCDS) - Admission - version 4.00 [CMS Assessment]"
        }
      end

      #-------------------------------------------------------------------------

      def filter(item)
        [ "Section-3/C1610", "Section-37/GG0130", "Section-37/GG0170" ].include?(item[:linkId])
      end

    end

  end
end
