# MedicationRequest Model
class MedicationRequest < Resource
  attr_reader :id, :fhir_resource, :status, :intent, :medication,
              :authored_on, :reason, :dosage_instruction

  def initialize(fhir_medication_request)
    @id = fhir_medication_request.id
    @fhir_resource = fhir_medication_request
    @status = @fhir_resource.status
    @intent = @fhir_resource.intent
    @medication = coding_string(@fhir_resource.medicationCodeableConcept&.coding)
    @authored_on = parse_date(@fhir_resource.authoredOn)
    @reason = coding_string(@fhir_resource.reasonCode.first.coding)
    @dosage_instruction = @fhir_resource.dosageInstruction.map(&:text)&.join(', ')
  end
end
