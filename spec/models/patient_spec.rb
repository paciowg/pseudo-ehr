# frozen_string_literal: true

# spec/models/patient_spec.rb
require 'rails_helper'

RSpec.describe Patient do
  let(:fhir_patient) { FHIR::Patient.new }

  describe 'initializing from a FHIR patient' do
    before do
      allow(fhir_patient).to receive_messages(
        id: '12345', name: [double('Name', given: ['John'],
                                           family: 'Doe', suffix: ['Jr.'])], birthDate: '1985-10-15',
        gender: 'male', address: [double('Address', line: ['123 Elm St'],
                                                    city: 'Springfield', state: 'IL', postalCode: '12345',
                                                    country: 'USA',
                                                    period: double('Period', start: '2022-01-01'))],
        telecom: [double('Telecom', system: 'phone', value: '123-456-7890'),
                  double('Telecom', system: 'email', value: 'john.doe@example.com')],
        identifier: [double('Identifier', value: 'MR12345', type: double('Type',
                                                                         coding: [double('Coding', code: 'MR')]))],
        maritalStatus: double('MaritalStatus', coding: [double('Coding', display: 'Married')]),
        extension: []
      )
    end

    context 'when attributes are present' do
      it 'formats the name correctly' do
        patient = described_class.new(fhir_patient)
        expect(patient.name).to eq('John Doe')
      end

      it 'formats the address correctly' do
        patient = described_class.new(fhir_patient)
        expect(patient.address).to eq('123 Elm St, Springfield, IL, 12345, USA')
      end

      it 'formats the phone correctly' do
        patient = described_class.new(fhir_patient)
        expect(patient.phone).to eq('123-456-7890')
      end

      it 'formats the email correctly' do
        patient = described_class.new(fhir_patient)
        expect(patient.email).to eq('john.doe@example.com')
      end

      it 'parses the date of birth correctly' do
        patient = described_class.new(fhir_patient)
        expect(patient.dob).to eq('1985-10-15')
      end

      it 'parses the medical record number correctly' do
        patient = described_class.new(fhir_patient)
        expect(patient.medical_record_number).to eq('MR12345')
      end

      it 'parses the gender correctly' do
        patient = described_class.new(fhir_patient)
        expect(patient.gender).to eq('male')
      end

      it 'parses the marital status correctly' do
        patient = described_class.new(fhir_patient)
        expect(patient.marital_status).to eq('Married')
      end
    end

    context 'when attributes are missing' do
      context 'when name is missing' do
        before { allow(fhir_patient).to receive(:name).and_return(nil) }

        it 'returns "XXXXXX XXXXXX"' do
          patient = described_class.new(fhir_patient)
          expect(patient.name).to eq('XXXXXX XXXXXX')
        end
      end

      context 'when address is missing' do
        before { allow(fhir_patient).to receive(:address).and_return(nil) }

        it 'returns "No address provided"' do
          patient = described_class.new(fhir_patient)
          expect(patient.address).to eq('No address provided')
        end
      end

      context 'when telecom is missing' do
        before { allow(fhir_patient).to receive(:telecom).and_return(nil) }

        it 'returns dasshes ("--") for phone and email' do
          patient = described_class.new(fhir_patient)
          expect(patient.phone).to eq('--')
          expect(patient.email).to eq('--')
        end
      end

      context 'when date of birth is missing' do
        before { allow(fhir_patient).to receive(:birthDate).and_return(nil) }

        it 'returns "--" for dob' do
          patient = described_class.new(fhir_patient)
          expect(patient.dob).to eq('--')
        end
      end

      context 'when medical record number is missing' do
        before { allow(fhir_patient).to receive(:identifier).and_return([]) }

        it 'returns "--" for medical_record_number' do
          patient = described_class.new(fhir_patient)
          expect(patient.medical_record_number).to be_nil
        end
      end

      context 'when gender is missing' do
        before { allow(fhir_patient).to receive(:gender).and_return(nil) }

        it 'returns "--" for gender' do
          patient = described_class.new(fhir_patient)
          expect(patient.gender).to eq('--')
        end
      end

      context 'when marital status is missing' do
        before { allow(fhir_patient).to receive(:maritalStatus).and_return(nil) }

        it 'returns "--" for marital_status' do
          patient = described_class.new(fhir_patient)
          expect(patient.marital_status).to eq('--')
        end
      end

      context 'when extensions are missing' do
        before { allow(fhir_patient).to receive(:extension).and_return([]) }

        it 'returns "--" for race, ethnicity, and birthsex' do
          patient = described_class.new(fhir_patient)
          expect(patient.race).to eq('--')
          expect(patient.ethnicity).to eq('--')
          expect(patient.birthsex).to eq('--')
        end
      end
    end
  end
end
