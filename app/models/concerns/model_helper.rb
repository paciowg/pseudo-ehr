# frozen_string_literal: true

# app/models/concerns/model_helper.rb
module ModelHelper
  extend ActiveSupport::Concern

  def format_phone(fhir_telecom_arr)
    phone_numbers = fhir_telecom_arr&.select do |telecom|
      telecom.system == 'phone'
    end&.map(&:value)

    phone_numbers.present? ? phone_numbers.join(', ') : '--'
  end

  def format_email(fhir_telecom_arr)
    email_addresses = fhir_telecom_arr&.select do |telecom|
      telecom.system == 'email'
    end&.map(&:value)

    email_addresses.present? ? email_addresses.join(', ') : '--'
  end

  def format_name(fhir_name_array)
    # latest_name = latest_start_date_object(fhir_name_array)
    latest_name = fhir_name_array&.first

    given_names = latest_name&.given&.join(' ') || 'XXXXXX'
    family_name = latest_name&.family || 'XXXXXX'
    { first_name: given_names, last_name: family_name }
  end

  def format_address(fhir_address_arr)
    latest_address = latest_start_date_object(fhir_address_arr)
    return 'No address provided' if latest_address.nil?

    line = latest_address.line.join(', ') if latest_address.line
    city = latest_address.city
    state = latest_address.state
    postal_code = latest_address.postalCode
    country = latest_address.country

    [line, city, state, postal_code, country].compact.join(', ')
  end

  def latest_start_date_object(array)
    return if array.nil?

    latest_object = nil
    latest_start_date = nil

    array.each do |item|
      next unless item.period&.start

      start_date = Date.parse(item.period.start)

      if latest_start_date.nil? || start_date > latest_start_date
        latest_start_date = start_date
        latest_object = item
      end
    end

    latest_object.nil? ? array.first : latest_object
  end
end
