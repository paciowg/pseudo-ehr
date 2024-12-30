# DiagnosticReport Model
class DiagnosticReport < Resource
  attr_reader :id, :fhir_resource, :status, :effective_datetime, :last_updated, :code, :subject,
              :encounter, :issued, :performer, :result, :media_link, :presented_form

  def initialize(fhir_diagnostic_report, bundle_entries)
    @id = fhir_diagnostic_report.id
    @fhir_resource = fhir_diagnostic_report
    @status = @fhir_resource.status
    @effective_datetime = @fhir_resource.effectiveDateTime.presence
    @last_updated = parse_date(@fhir_resource.meta&.lastUpdated).presence || '--'
    # TODO: laboratory slice
    @code = coding_string(@fhir_resource.code&.coding)
    @subject = @fhir_resource.subject&.reference
    @encounter = @fhir_resource&.encounter&.display&.gsub('_', ' ').presence || '--'
    @issued = parse_date(@fhir_resource.issued).presence || '--'
    @performer = @fhir_resource.performer.map(&:display)&.join(', ').presence || '--'
    @result = @fhir_resource.result.map(&:display)&.join(', ')&.gsub('_', ' ').presence || '--'
    @media_link = @fhir_resource.media.map(&:link)&.join(', ').presence || '--'
    @presented_form = @fhir_resource.presentedForm&.map(&:contentType)&.join(', ').presence || '--'
  end
end
