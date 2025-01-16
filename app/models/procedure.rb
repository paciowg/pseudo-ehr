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
                   parse_provider_name(c&.actor, bundle_entries)
                 end&.join(', ').presence || '--'
    @asserter = parse_provider_name(@fhir_resource.asserter, bundle_entries)
    @category = '--'
    @reason_code = @fhir_resource.reasonCode&.map { |c| coding_string(c.coding) }&.join(', ').presence || '--'
    @reason_reference = @fhir_resource.reasonReference.map do |each|
      find_condition(each, bundle_entries)
    end&.join(', ').presence || '--'
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
