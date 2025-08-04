class DetectedIssue < Resource
  attr_reader :id, :fhir_resource, :status, :author, :severity, :detail, :code,
              :reference, :implicated, :evidences, :mitigations, :patient_id, :patient,
              :identified_date_time, :identified_period

  def initialize(fhir_detected_issue, bundle_entries = [])
    @fhir_resource = fhir_detected_issue
    @id = fhir_detected_issue.id
    @patient_id = @fhir_resource.patient&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @author = parse_provider_name(@fhir_resource.author, bundle_entries)
    @status = fhir_detected_issue.status
    @severity = fhir_detected_issue.severity
    @detail = fhir_detected_issue.detail
    @code = parse_codeable_concept(fhir_detected_issue.code)
    @reference = fhir_detected_issue.reference
    @implicated = parse_implicated
    @evidences = parse_evidences
    @mitigations = parse_mitigations(bundle_entries)
    @identified_date_time = fhir_detected_issue.identifiedDateTime
    @identified_period = fhir_detected_issue.identifiedPeriod

    self.class.update(self)
  end

  def identified_date
    return parse_date(identified_date_time) if identified_date_time.present?

    if identified_period.present?
      start_date = parse_date(identified_period.start)
      end_date = parse_date(identified_period.end)

      return "#{start_date} - #{end_date}" if valid_date?(start_date) && valid_date?(end_date)
      return "From #{start_date}" if valid_date?(start_date)
      return "Until #{end_date}" if valid_date?(end_date)
    end

    '--'
  rescue StandardError
    '--'
  end

  private

  def parse_implicated
    # implicated is an array of references to any resource that is relevant to the issue
    # We cannot constantize here because we don't know if the resource type is defined in our app
    # For simplicity, we will just return the display string if available, otherwise the reference
    @fhir_resource.implicated&.map do |ref|
      if ref.display.present?
        ref.display
      elsif ref.reference.present?
        ref.reference
      end
    end&.compact || []
  end

  def parse_evidences
    @fhir_resource.evidence&.flat_map do |evidence|
      codes = evidence.code&.map { |c| parse_codeable_concept(c) } || []
      codes.delete('--')

      details = evidence.detail&.map do |ref|
        if ref.display.present?
          ref.display
        elsif ref.reference.present?
          ref.reference
        end
      end&.compact || []

      codes.presence || details
    end&.compact || []
  end

  def parse_mitigations(bundle_entries)
    @fhir_resource.mitigation&.map do |mitigation|
      action = parse_codeable_concept(mitigation.action)
      author = parse_provider_name(mitigation.author, bundle_entries)
      date = parse_date(mitigation.date)

      { action:, date:, author: }
    end&.compact || []
  end

  def valid_date?(date)
    date.present? && date != '--'
  end
end
