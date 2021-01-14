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

      before_action :setup_fhir_clients  # Make sure we're connected to the servers

      #-------------------------------------------------------------------------

      def create
        # TODO - Need to eliminate this...
        params.permit!

        @sdc_questionnaire_response = params
        @questionnaire = get_questionnaire(@sdc_questionnaire_response[:questionnaire])

        # Collect all of the LOINC codes for the questions.  We'll need them
        # later to populate the PACIO observation codes.
        parse_questionnaire

        # Send questionnaire response to prototype quality reporting system (pQRS)
        # @fhir_qual_rpt_client.begin_transaction
        #   #Write the original questionnaire response
        #   questionnaire_response = FHIR::QuestionnaireResponse.new(@sdc_questionnaire_response)
        #   @fhir_qual_rpt_client.add_transaction_request('POST', nil, questionnaire_response,
        #                                         nil, full_url(questionnaire_response))
        # reply = @fhir_qual_rpt_client.end_transaction

        # Send questionnaire response and associated PACIO observations to 
        # Health Data Manager
        @fhir_data_mgr_client.begin_transaction
          #Write the original questionnaire response
          questionnaire_response = FHIR::QuestionnaireResponse.new(@sdc_questionnaire_response)
          @fhir_data_mgr_client.add_transaction_request('POST', nil, questionnaire_response,
                                                nil, full_url(questionnaire_response))

          # Convert questionnaire response data into PACIO resources
          extract_data_from_questionnaire_response
        reply = @fhir_data_mgr_client.end_transaction

        head(reply.code)
      end

      #-------------------------------------------------------------------------
      private
      #-------------------------------------------------------------------------

      def setup_fhir_clients
        @fhir_data_mgr_client ||= FHIR::Client.new(HEALTH_DATA_MGR)
        @fhir_qual_rpt_client ||= FHIR::Client.new(PQRS_SERVER)
      end

      #-------------------------------------------------------------------------

      def get_questionnaire(url)
        response = RestClient.get(url)
        JSON.parse(response.body)
      end

      #-------------------------------------------------------------------------

      def parse_questionnaire
        @questions = {}
        parse_questionnaire_node(@questionnaire["item"])
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
        # Create top-level bundled status observation
        bundled_observation = init_base_observation(@sdc_questionnaire_response)
        bundled_observation.category = category('survey')
        bundled_observation.meta = meta('http://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bfs') 
        bundled_observation.code = bundled_status_code

        # Extract all of the individual responses
        extract_node(@sdc_questionnaire_response, bundled_observation)
        @fhir_data_mgr_client.add_transaction_request('POST', nil, bundled_observation, nil,
                                              full_url(bundled_observation))
      end

      #-------------------------------------------------------------------------

      def extract_node(fhir_questionnaire_response, bundled_observation, items = nil)
        items = fhir_questionnaire_response if items.nil?

        if items[:item].present?
          items[:item].each do |item|
            if item[:item].present?
              puts "Node item[:linkId] = #{item[:linkId]}"
              # node_observation = init_base_observation(item)
              # node_observation.meta = node_meta(item)

              # bundled_observation.hasMember << reference(node_observation)

              extract_node(item, bundled_observation, item)
              # puts "    Adding node ID = #{node_observation.id}"
              # puts "    Observation.code = #{node_observation.code}"
              # @fhir_data_mgr_client.add_transaction_request('POST', nil, node_observation)
           else
              extract_leaf(item, bundled_observation, item)
            end
          end
        end
      end

      #-------------------------------------------------------------------------

      def extract_leaf(fhir_questionnaire_response, bundled_observation, item)
        if item[:answer].present?
          puts "Leaf item[:linkId] = #{item[:linkId]}"
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

          puts "    Adding leaf ID = #{fhir_observation.id}"
          puts "    Observation.code = #{fhir_observation.code}"
          @fhir_data_mgr_client.add_transaction_request('POST', nil, fhir_observation, nil,
                                                full_url(fhir_observation))
          bundled_observation.hasMember << reference(fhir_observation)
        end
      end

      #-------------------------------------------------------------------------

      def init_base_observation(fhir_questionnaire_response)
        fhir_observation = FHIR::Observation.new
        id = unique_id

        fhir_observation.id                  = id
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
        fhir_observation.extension           = extension(@sdc_questionnaire_response)

        fhir_observation
      end

      #-------------------------------------------------------------------------

      def full_url(resource)
        "#{HEALTH_DATA_MGR}/Observation/#{resource.id}"
      end

      #-------------------------------------------------------------------------

      def reference(resource)
        { 
          reference: "#{HEALTH_DATA_MGR}/Observation/#{resource.id}" 
        }
      end

      #-------------------------------------------------------------------------

      def questionnaire_name(fhir_questionnaire_response)
        fhir_questionnaire_response[:questionnaire]
      end

      #-------------------------------------------------------------------------

      def unique_id
        Digest::SHA1.hexdigest([Time.now, rand].join)
      end

      #-------------------------------------------------------------------------

      def performer(fhir_questionnaire_response)
        author = fhir_questionnaire_response[:author][:reference]

        [
          {
            "reference": "#{HEALTH_DATA_MGR}/#{author}"
          },
          {
            "reference": "#{HEALTH_DATA_MGR}/#{PRACTITIONER_ROLE[author]}"
          },
          {
            "reference": "#{HEALTH_DATA_MGR}/#{ORGANIZATION[author]}",
            "display": "Organization"
          }
        ]
      end

      #-------------------------------------------------------------------------

      def extension(fhir_questionnaire_response)
        author = fhir_questionnaire_response[:author][:reference]

        [
          {
            "url": "http://hl7.org/fhir/StructureDefinition/event-location",
            "valueReference": {
              "reference": "#{HEALTH_DATA_MGR}/#{LOCATION[author]}"
            }
          }
        ]
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

      # def node_meta(item)
      #   meta(META_MAPPING[item[:linkId]] || 
      #               "https://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-bfs")
      # end

      #-------------------------------------------------------------------------

      def leaf_meta(bundled_observation)
        bundled_type = bundled_observation.meta[:profile].first
        if bundled_type.ends_with?('pacio-bfs')
          meta("http://paciowg.github.io/functional-status-ig/StructureDefinition/pacio-fs")
        else
          meta("http://paciowg.github.io/cognitive-status-ig/StructureDefinition/pacio-cs")
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
          coding: @questions[fhir_questionnaire_response[:linkId]] 
        }
      end

      #-------------------------------------------------------------------------

      def bundled_status_code
        { 
          coding: [
            {
              system:   @questionnaire["code"].first["system"], 
              # code:     @questionnaire["code"].first["code"], 
              # display:  @questionnaire["title"]
              code: "88330-6",
              display: "Mobility - admission performance during 3 day assessment period [CMS Assessment]"
            }
          ]
        }
      end

      #-------------------------------------------------------------------------

      PRACTITIONER_ROLE = {
        "Practitioner/Practitioner-SallySmith"    => "PractitionerRole/Role-PT",
        "Practitioner/Practitioner-RonMarble"     => "PractitionerRole/Role-PT",
        "Practitioner/Practitioner-JenCadbury"    => "PractitionerRole/Role-PT",
        "Practitioner/Practitioner-DanielGranger" => "PractitionerRole/Role-PT",
        "Practitioner/Practitioner-LunaBaskins"   => "PractitionerRole/Role-PT",
        "Practitioner/Practitioner-ScottDumble"   => "PractitionerRole/Role-PT",
        "Practitioner/Practitioner-JohnSmith"     => "PractitionerRole/provider-role-pcp",
        "Practitioner/Practitioner-JennyGlass"    => "PractitionerRole/Role-SLP",
        "Practitioner/Practitioner-HoneyJones"    => "PractitionerRole/Role-SLP",
      }.freeze

      #-------------------------------------------------------------------------

      ORGANIZATION = {
        "Practitioner/Practitioner-SallySmith"    => "Organization/Org-01",
        "Practitioner/Practitioner-RonMarble"     => "Organization/Org-01",
        "Practitioner/Practitioner-JenCadbury"    => "Organization/Org-02",
        "Practitioner/Practitioner-DanielGranger" => "Organization/Org-02",
        "Practitioner/Practitioner-LunaBaskins"   => "Organization/Org-03",
        "Practitioner/Practitioner-ScottDumble"   => "Organization/Org-03",
        "Practitioner/Practitioner-JohnSmith"     => "Organization/Org-01",
        "Practitioner/Practitioner-JennyGlass"    => "Organization/Org-01",
        "Practitioner/Practitioner-HoneyJones"    => "Organization/Org-02",
      }.freeze

      #-------------------------------------------------------------------------

      LOCATION = {
        "Practitioner/Practitioner-SallySmith"    => "Location/Org-Loc-01",
        "Practitioner/Practitioner-RonMarble"     => "Location/Org-Loc-01",
        "Practitioner/Practitioner-JenCadbury"    => "Location/Org-Loc-02",
        "Practitioner/Practitioner-DanielGranger" => "Location/Org-Loc-02",
        "Practitioner/Practitioner-LunaBaskins"   => "Location/Org-Loc-03",
        "Practitioner/Practitioner-ScottDumble"   => "Location/Org-Loc-03",
        "Practitioner/Practitioner-JohnSmith"     => "Location/Org-Loc-01",
        "Practitioner/Practitioner-JennyGlass"    => "Location/Org-Loc-01",
        "Practitioner/Practitioner-HoneyJones"    => "Location/Org-Loc-02",        
      }.freeze
    end

  end
end
