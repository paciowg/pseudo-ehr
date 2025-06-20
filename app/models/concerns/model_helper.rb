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

  # Extract the resourceType and id from FHIR reference
  def extract_resource_data(entry)
    return unless entry&.reference.present? && entry.reference&.split('/')&.length == 2

    entry.reference&.split('/')
  end

  # Extract a FHIR resource from bundle
  def get_object_from_bundle(fhir_reference, fhir_bundle)
    resource_type, resource_id = extract_resource_data(fhir_reference)
    return unless resource_type && resource_id

    fhir_bundle.find do |resource|
      resource.resourceType == resource_type && resource.id == resource_id
    end
  end

  def get_custodian(ref, fhir_bundle)
    org = get_object_from_bundle(ref, fhir_bundle)
    org&.name || '--'
  end

  #-----------------------------------------------------------------------------
  # TODO: This is temporary. should get api keys to read code values from https://cts.nlm.nih.gov/fhir/login.html
  def category_string(category_list)
    text = []

    category_list&.each do |category|
      text << coding_string(category.coding)
    end

    text.join(', ')
  end

  def coding_string(coding_list)
    # TODO: Temporary! see above todo
    code = {
      '100826-7' => 'Portable medical order &or advance directive review',
      '100827-5' => 'Portable medical order discussion participants',
      '104144-1' => 'Mental Health Directive',
      '81334-5' => 'Personal advance care plan',
      '42348-3' => 'Advance directives',
      '93037-0' => 'Portable Medical Order',
      '92664-2' => 'Combined Living Will and Medical Power of Attorney'
    }
    system = {
      'http://loinc.org' => 'LOINC',
      'http://snomed.info/sct' => 'SNOMED'
    }

    text = []

    coding_list&.each do |coding|
      display = coding.display || code[coding.code]
      coding_system = system[coding.system]
      coding_code = coding_system.present? ? "#{coding_system} #{coding.code}" : coding.code
      display = "#{display} (#{coding_code})" if display.present?
      text << (display.presence || coding_code)
    end

    text.compact.empty? ? '--' : text.compact.join(', ')
  end
  #-----------------------------------------------------------------------------

  def parse_date(date_string)
    return '--' if date_string.blank?

    date_string = "#{date_string}-01" if date_string.split('-').size == 2

    DateTime.parse(date_string).strftime('%b %d, %Y')
  end
  #-----------------------------------------------------------------------------

  def parse_provider_name(provider_ref, bundle_entries)
    display = provider_ref.try(:display)
    return display if display.present?
    return '--' unless provider_ref.try(:reference)

    resource_type, resource_id = provider_ref.reference.split('/')
    provider_resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }
    return '--' unless provider_resource

    case resource_type
    when 'Practitioner', 'Patient', 'RelatedPerson'
      format_name(provider_resource.name) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    when 'Organization', 'Location'
      provider_resource.name
    when 'PractitionerRole'
      role = provider_resource.try(:code)&.first&.coding&.first&.display
      name = provider_resource.practitioner.display
      if name
        return role.present? ? "#{name} | #{role}" : name
      end

      practioner_id = provider_resource.practitioner.reference.split('/').last
      practitioner = bundle_entries.find { |res| res.resourceType == 'Practitioner' && res.id == practioner_id }
      format_name(practitioner.name) => { first_name:, last_name: }
      name = "#{first_name} #{last_name}"
      role.present? ? "#{name} | #{role}" : name
    end
  end
end
