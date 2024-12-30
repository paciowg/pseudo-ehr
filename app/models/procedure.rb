# Procedure Model
class Procedure < Resource
  attr_reader :id, :fhir_resource, :status, :status_reason, :code, :performer, :date, :procedure_display, :reason_code,
              :asserter, :encounter, :category, :reason_reference, :bodysite, :outcome, :complication, :note

  def initialize(fhir_procedure, bundle_entries)
    @id = fhir_procedure.id
    @fhir_resource = fhir_procedure
    @status = @fhir_resource.status
    @status_reason = @fhir_resource.statusReason.presence || '--'
    @code = coding_string(@fhir_resource.code&.coding).presence || '--'
    @encounter = @fhir_resource.encounter == [] ? '--' : @fhir_resource.encounter&.reference
    @date = @fhir_resource.performedDateTime
    @performer = parse_provider_name(@fhir_resource.performer, bundle_entries)
    @asserter = parse_provider_name(@fhir_resource.asserter, bundle_entries)
    @category = fhir_procedure.category&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @reason_code = @fhir_resource.reasonCode.presence || '--'
    @reason_reference = @fhir_resource.reasonReference == [] ? '--' : @fhir_resource.reasonReference&.reference
    @bodysite = @fhir_resource.bodySite.presence || '--'
    @outcome = coding_string(@fhir_resource.outcome&.coding).presence || '--'
    @complication = @fhir_resource.complication.presence || '--'
    @note = @fhir_resource.note.presence || '--'
  end
end
