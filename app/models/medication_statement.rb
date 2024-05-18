# frozen_string_literal: true

# MedicationStatement Model
class MedicationStatement < Resource
  attr_reader :id, :fhir_resource, :status, :medication,
              :date_asserted, :info_source, :reason, :dosage

  def initialize(fhir_medication_statement, bundle_entries)
    @id = fhir_medication_statement.id
    @fhir_resource = fhir_medication_statement
    @status = @fhir_resource.status
    @medication = coding_string(@fhir_resource.medicationCodeableConcept&.coding)
    @date_asserted = parse_date(@fhir_resource.dateAsserted)
    @info_source = read_info_source(bundle_entries)
    Rails.logger.debug @fhir_resource.reasonCode
    @reason = coding_string(@fhir_resource.reasonCode.first.try(:coding))
    @dosage = @fhir_resource.dosage.map(&:text)&.join(', ')
  end

  private

  def read_info_source(bundle_entries)
    source = @fhir_resource.informationSource
    return '--' unless source

    return source.display if source.display

    resource_type, resource_id = source.reference.split('/')

    resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }
    return '--' unless resource

    case resource_type
    when 'Practitioner', 'Patient', 'RelatedPerson'
      format_name(resource.name) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    when 'Organization'
      resource.name
    when 'PractitionerRole'
      name = resource.practitioner.display
      return name if name

      practioner_id = resource.practitioner.reference.split('/').last
      practitioner = bundle_entries.find { |res| res.resourceType == 'Practitioner' && res.id == practioner_id }
      format_name(practitioner.name) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    end
  end
end
