# Procedure Model
class Procedure < Resource
  attr_reader :id, :fhir_resource, :status, :status_reason, :code, :performer, :date, :procedure_display, :reason_code,
              :asserter, :encounter, :category, :reason_reference, :bodysite, :outcome, :complication, :note,
              :date_period

  def initialize(fhir_procedure, bundle_entries)
    @id = fhir_procedure.id
    @fhir_resource = fhir_procedure
    @status = @fhir_resource.status
    @status_reason = @fhir_resource.statusReason.presence || '--'
    @code = coding_string(@fhir_resource.code&.coding).presence || '--'
    @encounter = @fhir_resource.encounter&.reference.presence || '--'
    @date = @fhir_resource.performedDateTime.presence || '--'
    @date_period = (@fhir_resource.performedPeriod&.start&.+ ' to ' + @fhir_resource.performedPeriod&.end).presence || '--'
    @performer = @fhir_resource.performer&.map do |c|
                   c&.actor&.reference
                 end&.join(', ')&.split('/')&.last.presence || '--'
    @asserter = @fhir_resource.asserter.reference&.split('/')&.last.presence || '--'
    @category = '--'
    @reason_code = @fhir_resource.reasonCode&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @reason_reference = @fhir_resource.reasonReference.map(&:reference)&.join(', ')&.split('/')&.last.presence || '--'
    @bodysite = @fhir_resource.bodySite&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @outcome = coding_string(@fhir_resource.outcome&.coding).presence || '--'
    @complication = @fhir_resource.complication.presence || '--'
    @note = @fhir_resource.note.presence || '--'
  end

  def procedure_string(actor)
    name = actor.reference
    text << name

    text.compact.empty? ? '--' : text.compact.join(', ')
  end
end
