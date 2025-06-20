# RelatedPerson Model
class RelatedPerson < Resource
  attr_reader :id, :fhir_resource, :name, :relationship, :telecom, :gender, :birth_date,
              :address, :period, :active, :patient, :patient_id

  def initialize(fhir_related_person, _bundle_entries = [])
    @id = fhir_related_person.id
    @fhir_resource = fhir_related_person
    @patient_id = @fhir_resource.patient&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)

    name_hash = format_name(fhir_related_person.name)
    @name = "#{name_hash[:first_name]} #{name_hash[:last_name]}"

    @relationship = category_string(fhir_related_person.relationship)
    @telecom = fhir_related_person.telecom
    @gender = fhir_related_person.gender
    @birth_date = parse_date(fhir_related_person.birthDate)
    @address = format_address(fhir_related_person.address)
    @period = format_period(fhir_related_person.period)
    @active = fhir_related_person.active

    self.class.update(self)
  end

  def phone
    format_phone(@telecom)
  end

  def email
    format_email(@telecom)
  end

  private

  def format_period(period)
    return '--' if period&.start.blank?

    start_date = parse_date(period.start)
    end_date = period.end.present? ? parse_date(period.end) : 'present'

    "#{start_date} to #{end_date}"
  end
end
