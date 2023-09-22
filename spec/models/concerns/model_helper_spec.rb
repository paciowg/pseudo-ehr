# frozen_string_literal: true

# spec/models/concerns/model_helper_spec.rb

require 'rails_helper'

RSpec.describe ModelHelper, type: :model do
  let(:dummy_class) { Class.new { include ModelHelper } }
  let(:dummy_instance) { dummy_class.new }

  Telecom = Struct.new(:system, :value)
  Name = Struct.new(:given, :family, :suffix)
  Address = Struct.new(:line, :city, :state, :postalCode, :country, :period)
  Period = Struct.new(:start)

  describe '#format_phone' do
    context 'with valid phone numbers' do
      it 'formats phone numbers correctly' do
        fhir_telecom_arr = [Telecom.new('phone', '+1234567890'), Telecom.new('email', 'test@example.com'),
                            Telecom.new('phone', '+0987654321')]
        expect(dummy_instance.format_phone(fhir_telecom_arr)).to eq('+1234567890, +0987654321')
      end
    end

    context 'with no phone numbers' do
      it 'returns dashes "--"' do
        fhir_telecom_arr = [Telecom.new('email', 'test@example.com')]
        expect(dummy_instance.format_phone(fhir_telecom_arr)).to eq('--')
      end
    end
  end

  describe '#format_email' do
    context 'with valid email addresses' do
      it 'formats email addresses correctly' do
        fhir_telecom_arr = [Telecom.new('phone', '+1234567890'), Telecom.new('email', 'test@example.com'),
                            Telecom.new('phone', '+0987654321'), Telecom.new('email', 'user@example.com')]
        expect(dummy_instance.format_email(fhir_telecom_arr)).to eq('test@example.com, user@example.com')
      end
    end

    context 'with no email addresses' do
      it 'returns dashes "--"' do
        fhir_telecom_arr = [Telecom.new('phone', '+1234567890')]
        expect(dummy_instance.format_email(fhir_telecom_arr)).to eq('--')
      end
    end
  end

  describe '#format_name' do
    context 'with valid name' do
      it 'returns a hash with first_name and last_name keys and values' do
        fhir_name_array = [Name.new(%w[John Doe], 'Smith', ['Jr.'])]
        expect(dummy_instance.format_name(fhir_name_array)[:first_name]).to eq('John Doe')
        expect(dummy_instance.format_name(fhir_name_array)[:last_name]).to eq('Smith')
      end
    end

    context 'with no name provided' do
      it 'returns "XXXXXX" for first_name and last_name' do
        expect(dummy_instance.format_name([])[:first_name]).to eq('XXXXXX')
        expect(dummy_instance.format_name([])[:last_name]).to eq('XXXXXX')
      end
    end
  end

  describe '#format_address' do
    context 'with valid address' do
      it 'formats addresses correctly' do
        fhir_address_arr = [Address.new(['123 Main St'], 'Springfield', 'IL', '12345', 'USA', nil)]
        expect(dummy_instance.format_address(fhir_address_arr)).to eq('123 Main St, Springfield, IL, 12345, USA')
      end
    end

    context 'with no address provided' do
      it 'returns "No address provided"' do
        expect(dummy_instance.format_address([])).to eq('No address provided')
      end
    end

    context 'without some address components' do
      it 'formats address excluding nil components' do
        fhir_address_arr = [Address.new(nil, 'Springfield', nil, '12345', 'USA', nil)]
        expect(dummy_instance.format_address(fhir_address_arr)).to eq('Springfield, 12345, USA')
      end
    end
  end

  describe '#latest_start_date_object' do
    context 'with items having periods' do
      it 'returns the latest start date item' do
        period1 = Period.new('2021-01-01')
        period2 = Period.new('2022-01-01')
        fhir_array = [Address.new(nil, 'Address1', nil, nil, nil, period1),
                      Address.new(nil, 'Address2', nil, nil, nil, period2)]

        expect(dummy_instance.latest_start_date_object(fhir_array)).to eq(fhir_array.last)
      end
    end

    context 'with items without periods' do
      it 'returns the first item' do
        fhir_array = [Address.new(nil, 'Address1', nil, nil, nil, nil),
                      Address.new(nil, 'Address2', nil, nil, nil, nil)]

        expect(dummy_instance.latest_start_date_object(fhir_array)).to eq(fhir_array.first)
      end
    end

    context 'with empty array' do
      it 'returns nil' do
        expect(dummy_instance.latest_start_date_object([])).to be_nil
      end
    end
  end
end
