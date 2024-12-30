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
    @request_intent = fhir_medication_request.reasonCode&.map { |c| coding_string(c.coding) }&.join(', ')
    @medication = coding_string(@fhir_resource.medicationCodeableConcept&.coding)
    @authored_on = parse_date(@fhir_resource.authoredOn)
    @requester = @fhir_resource&.requester.presence || '--'
    @category = fhir_medication_request.category&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @dosage_instruction = @fhir_resource.dosageInstruction.map(&:text)&.join(', ')
    @procedure_intent = coding_string(read_extension(@fhir_resource.extension))

    # TODO: connect resource
    @reason_reference = @fhir_resource.reasonReference.map(&:reference)&.join(', ').presence || '--'
    @reported = @fhir_resource.reportedBoolean.presence || '--'
    @reported_reference = @fhir_resource.reportedReference.presence || '--'
    @note = @fhir_resource.note.presence || '--'
  end

  def read_extension(extensions)
    extensions.each do |ext|
      if ext.url == 'http://hl7.org/fhir/us/mcode/StructureDefinition/mcode-procedure-intent'
        return ext&.valueCodeableConcept&.coding
      end
    end
  end
end
