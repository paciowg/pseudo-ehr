# DiagnosticReport Model
class DiagnosticReport < Resource
  attr_reader :id, :fhir_resource, :status, :effective_datetime, :last_updated, :code, :subject,
              :encounter, :issued, :performer, :result, :media_link, :presented_form

  def initialize(fhir_diagnostic_report, bundle_entries)
    @id = fhir_diagnostic_report.id
    @fhir_resource = fhir_diagnostic_report
    @status = @fhir_resource.status.presence || '--'
    @effective_datetime = parse_date(@fhir_resource.effectiveDateTime).presence || '--'
    @last_updated = parse_date(@fhir_resource.meta&.lastUpdated).presence || '--'
    # TODO: laboratory slice
    @code = coding_string(@fhir_resource.code&.coding).presence || '--'
    @subject = @fhir_resource.subject&.reference&.split('/')&.last.presence || '--'
    @encounter = @fhir_resource&.encounter&.display&.gsub('_', ' ').presence || '--'
    @issued = parse_date(@fhir_resource.issued).presence || '--'
    @performer = @fhir_resource.performer.map(&:reference)&.join(', ').presence || '--'
    @result = @fhir_resource.result.map do |each|
                retrieve_observation_date(each.reference, bundle_entries)
              end
    @media_link = @fhir_resource.media.map(&:link)&.join(', ').presence || '--'
    @presented_form = @fhir_resource.presentedForm&.map(&:contentType)&.join(', ').presence || '--'
  end

  def retrieve_observation_date(observation, bundle_entries)
    return 'Observation results not found.' if observation.blank?

    resource_type, id = observation&.split('/')
    bundle_entries.find { |entry| entry.resourceType == resource_type && entry.id == id }
  end
end
