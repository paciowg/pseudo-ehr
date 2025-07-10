# MedicationRequest Model
class MedicationRequest < Resource
  attr_reader :id, :fhir_resource, :status, :intent, :medication,
              :authored_on, :reason, :dosage_instruction, :patient_id,
              :patient, :requester, :request_intent, :reason_code,
              :status_reason, :procedure_intent, :reason_reference,
              :category, :reported, :reported_reference, :note

  def initialize(fhir_medication_request, bundle_entries = [])
    @id = fhir_medication_request.id
    @fhir_resource = fhir_medication_request
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = @fhir_resource.status
    @status_reason = coding_string(@fhir_resource.statusReason&.try(:coding))
    @intent = @fhir_resource.intent&.capitalize
    @request_intent = @fhir_resource.reasonCode&.map do |reason|
      coding_string(reason.try(&:coding))
    end&.join(', ').presence || '--'
    @medication = coding_string(@fhir_resource.medicationCodeableConcept&.coding)
    @authored_on = parse_date(@fhir_resource.authoredOn)
    @requester = parse_provider_name(@fhir_resource.requester, bundle_entries).presence || '--'
    @category = @fhir_resource.category&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @reason = coding_string(@fhir_resource.reasonCode.first&.coding)
    @dosage_instruction = @fhir_resource.dosageInstruction&.map(&:text)&.join(', ').presence || ''
    @procedure_intent = coding_string(read_extension(@fhir_resource.extension))
    @reason_reference = @fhir_resource.reasonReference&.map do |each|
      find_condition(each, bundle_entries)
    end&.compact&.join(', ').presence || '--'
    @reported = !@fhir_resource.reportedBoolean.nil?
    @reported_reference = parse_provider_name(@fhir_resource.reportedReference, bundle_entries)
    @note = @fhir_resource.note&.map(&:text)&.join(', ').presence || '--'

    self.class.update(self)
  end

  private

  def read_extension(extensions)
    extensions&.each do |ext|
      if ext.url == 'http://hl7.org/fhir/us/mcode/StructureDefinition/mcode-procedure-intent'
        return ext&.valueCodeableConcept&.coding
      end
    end

    nil
  end

  def find_condition(provider_ref, bundle_entries)
    return '--' unless provider_ref.try(:reference)

    resource_type, resource_id = provider_ref.reference.split('/')
    provider_resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }
    return '--' unless provider_resource

    condition = nil
    case resource_type
    when 'Condition'
      condition = coding_string(provider_resource&.code&.coding)
    end
    condition
  end
end
