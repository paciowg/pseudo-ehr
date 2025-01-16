# MedicationRequest Model
class MedicationRequests < Resource
  attr_reader :id, :fhir_resource, :status, :intent, :medication,
              :authored_on, :reason, :dosage_instruction, :requester, :request_intent, :reason_code,
              :status_reason, :procedure_intent, :reason_reference, :category, :reported, :reported_reference, :note

  def initialize(fhir_medication_request, bundle_entries)
    @id = fhir_medication_request.id
    @fhir_resource = fhir_medication_request
    @status = @fhir_resource.status
    @status_reason = @fhir_resource.statusReason.presence || '--'
    @intent = @fhir_resource.intent
    @request_intent = fhir_medication_request.reasonCode&.map do |c|
                        coding_string(c.coding)
                      end&.join(', ')
    @medication = coding_string(@fhir_resource.medicationCodeableConcept&.coding)
    @authored_on = parse_date(@fhir_resource.authoredOn)
    @requester = parse_provider_name(@fhir_resource.requester, bundle_entries).presence || '--'
    @category = fhir_medication_request.category&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @dosage_instruction = @fhir_resource.dosageInstruction.map(&:text)&.join(', ')
    @procedure_intent = coding_string(read_extension(@fhir_resource.extension))
    @reason_reference = @fhir_resource.reasonReference.map do |each|
      find_condition(each, bundle_entries)
    end&.join(', ').presence || '--'
    @reported = @fhir_resource.reportedBoolean.presence || '--'
    @reported_reference = @fhir_resource.reportedReference.presence || '--'
    @note = @fhir_resource.note.map(&:text)&.join(', ').presence || '--'
  end

  def read_extension(extensions)
    extensions.each do |ext|
      if ext.url == 'http://hl7.org/fhir/us/mcode/StructureDefinition/mcode-procedure-intent'
        return ext&.valueCodeableConcept&.coding
      end
    end
  end

  def find_condition(provider_ref, bundle_entries)
    return '--' unless provider_ref.try(:reference)

    resource_type, resource_id = provider_ref.reference.split('/')
    provider_resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }
    return '--' unless provider_resource

    case resource_type
    when 'Condition'
      condition = coding_string(provider_resource&.code&.coding)
    end
    condition
  end
end
