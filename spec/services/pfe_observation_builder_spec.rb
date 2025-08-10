require 'rails_helper'

RSpec.describe PfeObservationBuilder do
  subject(:builder) { described_class.new(questionnaire_response, questionnaire) }

  let(:qr_id) { 'qr-123' }
  let(:authored_date) { '2023-05-15T10:00:00Z' }
  let(:patient_id) { 'patient-123' }
  let(:practitioner_id) { 'practitioner-456' }

  let(:questionnaire_response) do
    FHIR::QuestionnaireResponse.new(
      id: qr_id,
      status: 'completed',
      authored: authored_date,
      subject: { reference: "Patient/#{patient_id}" },
      author: { reference: "Practitioner/#{practitioner_id}" },
      item: [
        {
          linkId: 'functional-mobility',
          text: 'Functional Mobility',
          item: [
            {
              linkId: 'mobility-score',
              text: 'Mobility Score',
              answer: [
                { valueInteger: 4 }
              ]
            }
          ]
        },
        {
          linkId: 'pain',
          text: 'Pain Assessment',
          answer: [
            { valueInteger: 2 }
          ]
        }
      ]
    )
  end

  let(:questionnaire) do
    FHIR::Questionnaire.new(
      id: 'q-123',
      status: 'active',
      code: [
        {
          system: 'http://loinc.org',
          code: '88330-6',
          display: 'Functional Assessment'
        }
      ],
      item: [
        {
          linkId: 'functional-mobility',
          text: 'Functional Mobility',
          code: [
            {
              system: 'http://loinc.org',
              code: '89387-5',
              display: 'Functional Mobility'
            }
          ],
          item: [
            {
              linkId: 'mobility-score',
              text: 'Mobility Score',
              code: [
                {
                  system: 'http://loinc.org',
                  code: '89390-9',
                  display: 'Mobility Score'
                }
              ]
            }
          ]
        },
        {
          linkId: 'pain',
          text: 'Pain Assessment',
          code: [
            {
              system: 'http://loinc.org',
              code: '72514-3',
              display: 'Pain severity'
            }
          ]
        }
      ]
    )
  end

  describe '#build' do
    let(:result) { builder.build }

    before do
      allow(PfeCategoryCodeExtractor).to receive(:extract)
        .and_return([
                      FHIR::CodeableConcept.new(
                        coding: [
                          {
                            system: described_class::US_CORE_CATEGORY_URL,
                            code: 'functional-status',
                            display: 'Functional Status'
                          }
                        ]
                      )
                    ])

      allow(PfeCategoryCodeExtractor).to receive(:collection_category_slice)
        .and_return([
                      FHIR::CodeableConcept.new(
                        coding: [
                          {
                            system: described_class::SURVEY_CATEGORY_URL,
                            code: 'survey'
                          }
                        ]
                      ),
                      FHIR::CodeableConcept.new(
                        coding: [
                          {
                            system: described_class::US_CORE_CATEGORY_URL,
                            code: 'functional-status',
                            display: 'Functional Status'
                          }
                        ]
                      ),
                      FHIR::CodeableConcept.new(
                        coding: [
                          {
                            system: described_class::PFE_DOMAIN_CATEGORY_URL,
                            code: 'BlockL2-d51',
                            display: 'Mobility'
                          }
                        ]
                      )
                    ])
    end

    it 'returns an array of observations' do
      expect(result).to be_an(Array)
      expect(result.size).to eq(3) # 2 item observations + 1 collection
    end

    it 'creates a collection observation' do
      collection = result.last
      expect(collection).to be_a(FHIR::Observation)
      expect(collection.meta.profile).to include(described_class::PFE_COLLECTION_PROFILE)
      expect(collection.derivedFrom.first.reference).to eq("QuestionnaireResponse/#{qr_id}")
      expect(collection.subject.reference).to eq("Patient/#{patient_id}")
      expect(collection.performer.first.reference).to eq("Practitioner/#{practitioner_id}")
      expect(collection.hasMember.size).to eq(2)
    end

    it 'creates individual observations for each answer' do
      mobility_obs = result.find { |obs| obs.code.coding.any? { |c| c.code == '89390-9' } }
      pain_obs = result.find { |obs| obs.code.coding.any? { |c| c.code == '72514-3' } }

      expect(mobility_obs).to be_present
      expect(mobility_obs.valueInteger).to eq(4)
      expect(mobility_obs.meta.profile).to include(described_class::PFE_SINGLE_OBS_PROFILE)

      expect(pain_obs).to be_present
      expect(pain_obs.valueInteger).to eq(2)
      expect(pain_obs.meta.profile).to include(described_class::PFE_SINGLE_OBS_PROFILE)
    end

    it 'assigns proper references in collection' do
      collection = result.last
      expect(collection.hasMember).to be_present

      member_refs = collection.hasMember.map { |ref| ref[:reference].split('/').last }
      observation_ids = result.first(2).map(&:id)

      expect(member_refs).to match_array(observation_ids)
    end

    it 'sets appropriate categories on all observations' do
      result.each do |obs|
        expect(obs.category).to be_present
        expect(obs.category.flat_map(&:coding).size).to be > 0
      end
    end

    context 'with device author' do
      let(:device_id) { 'device-789' }

      before do
        questionnaire_response.author = FHIR::Reference.new(reference: "Device/#{device_id}")
      end

      it 'adds device-use extension' do
        obs = result.first

        expect(obs.extension).to be_present

        device_ext = obs.extension.find { |ext| ext.url == described_class::EXT_DEVICE_USE }
        expect(device_ext).to be_present
        expect(device_ext.valueReference.reference).to eq("Device/#{device_id}")
      end
    end

    context 'with quantity values and units' do
      let(:questionnaire_response) do
        FHIR::QuestionnaireResponse.new(
          id: qr_id,
          status: 'completed',
          authored: authored_date,
          subject: { reference: "Patient/#{patient_id}" },
          author: { reference: "Practitioner/#{practitioner_id}" },
          item: [
            {
              linkId: 'weight',
              text: 'Weight',
              answer: [
                { valueDecimal: 75.5 }
              ]
            }
          ]
        )
      end

      let(:questionnaire) do
        FHIR::Questionnaire.new(
          id: 'q-123',
          status: 'active',
          item: [
            {
              linkId: 'weight',
              text: 'Weight',
              code: [
                {
                  system: 'http://loinc.org',
                  code: '29463-7',
                  display: 'Body weight'
                }
              ],
              extension: [
                {
                  url: 'http://hl7.org/fhir/StructureDefinition/questionnaire-unit',
                  valueCoding: {
                    system: 'http://unitsofmeasure.org',
                    code: 'kg',
                    display: 'kilograms'
                  }
                }
              ]
            }
          ]
        )
      end

      it 'creates a quantity with the correct unit' do
        weight_obs = result.first
        expect(weight_obs.valueQuantity).to be_present
        expect(weight_obs.valueQuantity.value).to eq(75.5)
        expect(weight_obs.valueQuantity.system).to eq('http://unitsofmeasure.org')
        expect(weight_obs.valueQuantity.code).to eq('kg')
        expect(weight_obs.valueQuantity.unit).to eq('kilograms')
      end
    end

    context 'with different answer value types' do
      # Add codes to the questionnaire items
      let(:questionnaire) do
        FHIR::Questionnaire.new(
          id: 'q-123',
          status: 'active',
          item: [
            {
              linkId: 'boolean-item',
              text: 'Boolean Item',
              code: [{ system: 'http://example.org', code: 'boolean-code' }]
            },
            {
              linkId: 'string-item',
              text: 'String Item',
              code: [{ system: 'http://example.org', code: 'string-code' }]
            },
            {
              linkId: 'date-item',
              text: 'Date Item',
              code: [{ system: 'http://example.org', code: 'date-code' }]
            },
            {
              linkId: 'coding-item',
              text: 'Coding Item',
              code: [{ system: 'http://example.org', code: 'coding-code' }]
            }
          ]
        )
      end

      let(:questionnaire_response) do
        FHIR::QuestionnaireResponse.new(
          id: qr_id,
          status: 'completed',
          authored: authored_date,
          subject: { reference: "Patient/#{patient_id}" },
          author: { reference: "Practitioner/#{practitioner_id}" },
          item: [
            {
              linkId: 'boolean-item',
              text: 'Boolean Item',
              answer: [{ valueBoolean: true }]
            },
            {
              linkId: 'string-item',
              text: 'String Item',
              answer: [{ valueString: 'Test String' }]
            },
            {
              linkId: 'date-item',
              text: 'Date Item',
              answer: [{ valueDate: '2023-05-15' }]
            },
            {
              linkId: 'coding-item',
              text: 'Coding Item',
              answer: [
                {
                  valueCoding: {
                    system: 'http://example.org/codes',
                    code: 'code-1',
                    display: 'Code 1'
                  }
                }
              ]
            }
          ]
        )
      end

      it 'correctly sets value types for different answers' do
        boolean_obs = result.find { |obs| obs.valueBoolean.present? }
        string_obs = result.find { |obs| obs.valueString.present? }
        date_obs = result.find { |obs| obs.valueDateTime.present? }
        coding_obs = result.find { |obs| obs.valueCodeableConcept.present? }

        # Make sure we found all the observations
        expect(boolean_obs).to be_present
        expect(string_obs).to be_present
        expect(date_obs).to be_present
        expect(coding_obs).to be_present

        # Check the value types are correctly set
        expect(boolean_obs.valueBoolean).to be(true)
        expect(string_obs.valueString).to eq('Test String')
        expect(date_obs.valueDateTime).to eq('2023-05-15')

        # Handle the coding value properly
        expect(coding_obs.valueCodeableConcept).to be_present
        expect(coding_obs.valueCodeableConcept.coding.first.code).to eq('code-1')
      end
    end

    context 'when QuestionnaireResponse has no items' do
      let(:questionnaire_response) do
        FHIR::QuestionnaireResponse.new(
          id: qr_id,
          status: 'completed',
          authored: authored_date,
          subject: { reference: "Patient/#{patient_id}" },
          author: { reference: "Practitioner/#{practitioner_id}" },
          item: []
        )
      end

      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end
  end
end
