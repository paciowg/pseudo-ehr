# frozen_string_literal: true

# spec/factories/fhir_patient.rb

FactoryBot.define do
  factory :fhir_patient, class: Hash do
    skip_create

    id { "pat-#{Faker::Number.unique.number(digits: 5)}" }
    resourceType { 'Patient' }

    meta do
      {
        profile: ['http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient']
      }
    end

    identifier do
      [
        {
          use: 'usual',
          type: {
            coding: [
              {
                system: 'http://terminology.hl7.org/CodeSystem/v2-0203',
                code: 'MR',
                display: 'Medical Record Number'
              }
            ],
            text: 'Medical Record Number'
          },
          system: 'http://hospital.smarthealthit.org',
          value: Faker::Number.unique.number(digits: 7).to_s
        }
      ]
    end

    active { true }

    name do
      [
        {
          family: Faker::Name.last_name.upcase,
          given: [Faker::Name.first_name, Faker::Name.middle_name].map(&:upcase),
          period: {
            start: Faker::Date.backward(days: 1500).to_s,
            end: Faker::Date.backward(days: 300).to_s
          }
        }
      ]
    end

    extension do
      [
        {
          extension: [
            {
              url: 'ombCategory',
              valueCoding: {
                system: 'urn:oid:2.16.840.1.113883.6.238',
                code: '2106-3',
                display: 'White'
              }
            }
            # ... more race extensions if needed
          ],
          url: 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'
        }
        # ... more extensions like ethnicity or birthsex if needed
      ]
    end

    initialize_with { attributes }
  end
end
