# frozen_string_literal: true

# Patient Model
class Patient < Resource
  attr_reader :id, :fhir_resource, :name, :dob, :medical_record_number, :gender, :address,
              :phone, :email, :race, :ethnicity, :marital_status, :birthsex

  def initialize(fhir_patient)
    @fhir_resource = fhir_patient

    extract_basic_attributes(fhir_patient)
    extract_contact_info(fhir_patient)
    extract_characteristics(fhir_patient)
  end

  private

  def extract_basic_attributes(fhir_patient)
    @id = fhir_patient.id
    @name = format_name(fhir_patient.name)
    @dob = fhir_patient.birthDate
    @gender = fhir_patient.gender
    @medical_record_number = extract_med_rec_num(fhir_patient.identifier)
    @marital_status = fhir_patient.maritalStatus&.coding&.first&.display
  end

  def extract_contact_info(fhir_patient)
    @address = format_address(fhir_patient.address)
    @phone = format_phone(fhir_patient.telecom)
    @email = format_email(fhir_patient.telecom)
  end

  def extract_characteristics(fhir_patient)
    characteristics = read_characteristics(fhir_patient.extension)
    @race = characteristics[:race]
    @ethnicity = characteristics[:ethnicity]
    @birthsex = characteristics[:birthsex]
  end

  def extract_med_rec_num(identifiers)
    identifiers.each do |id_obj|
      next unless id_obj.type&.coding

      id_obj.type.coding.each do |coding|
        return id_obj.value if coding.code == 'MR'
      end
    end
    nil
  end

  def read_characteristics(extensions)
    characteristics = { race: '', ethnicity: '', birthsex: nil }

    extensions.each do |ext|
      case ext.url
      when 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'
        characteristics[:race] = extract_display_values(ext)
      when 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity'
        characteristics[:ethnicity] = extract_display_values(ext)
      when 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex'
        characteristics[:birthsex] = ext.valueCode
      end
    end

    characteristics
  end

  def extract_display_values(extension)
    extension.extension.map do |sub_ext|
      sub_ext.valueCoding.display if sub_ext.url == 'ombCategory' && sub_ext.valueCoding
    end.compact.join(', ')
  end
end
