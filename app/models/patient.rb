# Patient Model
class Patient < Resource
  attr_reader :id, :fhir_resource, :first_name, :last_name, :name, :dob, :medical_record_number, :gender, :address,
              :phone, :email, :race, :ethnicity, :marital_status, :birthsex, :language, :patient_id, :emergency_contacts

  def initialize(fhir_patient)
    @fhir_resource = fhir_patient
    extract_name(fhir_patient)
    extract_basic_attributes(fhir_patient)
    extract_contact_info(fhir_patient)
    extract_characteristics(fhir_patient)
    @emergency_contacts = extract_emergency_contacts
    self.class.update(self)
  end

  class << self
    def filter_by_name(name)
      all.filter { |patient| patient.name.downcase.include?(name.downcase) }
    end
  end

  private

  def extract_basic_attributes(fhir_patient)
    @id = fhir_patient.id
    @patient_id = @id
    @dob = fhir_patient.birthDate || '--'
    @gender = fhir_patient.gender || '--'
    @medical_record_number = extract_med_rec_num(fhir_patient.identifier)
    @marital_status = marital_status_code_mapping(fhir_patient.maritalStatus&.coding&.first&.code)
    @language = fhir_patient.communication.first&.language&.coding&.first&.code&.upcase || '--'
  end

  def extract_name(fhir_patient)
    name_obj = format_name(fhir_patient.name)
    @first_name = name_obj[:first_name]
    @last_name = name_obj[:last_name]
    @name = "#{@first_name} #{@last_name}"
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

  def extract_emergency_contacts
    return [] unless @fhir_resource.contact

    @fhir_resource.contact.map do |contact|
      relationship = if (relationship_code = contact.relationship&.first&.coding&.first&.code)
                       relationship_code_mapping(relationship_code)
                     else
                       'Unknown'
                     end
      name = contact.name&.text.presence
      unless name
        name_obj = format_name([contact.name].flatten.compact)
        name = "#{name_obj[:first_name]} #{name_obj[:last_name]}"
      end
      phone = format_phone(contact.telecom)
      email = format_email(contact.telecom)
      address = contact.address.try(:text).presence || format_address([contact.address].flatten.compact)

      {
        name:,
        relationship:,
        phone:,
        email:,
        address:
      }
    end.compact
  end

  def read_characteristics(extensions)
    characteristics = { race: '--', ethnicity: '--', birthsex: '--' }

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

  def relationship_code_mapping(code)
    mapping = {
      'SONC' => 'Son',
      'DAUC' => 'Daughter',
      'SPOU' => 'Spouse',
      'FTH' => 'Father',
      'MTH' => 'Mother',
      'SIB' => 'Sibling',
      'FRND' => 'Friend',
      'CUST' => 'Custodian',
      'GUAR' => 'Guarantor',
      'PART' => 'Partner',
      'NOK' => 'Next of Kin',
      'DAUINLAW' => 'Daughter-in-law',
      'SONINLAW' => 'Son-in-law',
      'MTHINLAW' => 'Mother-in-law',
      'FTHINLAW' => 'Father-in-law'
    }

    mapping[code] || code || '--'
  end
end
