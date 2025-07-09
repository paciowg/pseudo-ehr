class DetectedIssue < Resource
  attr_reader :id, :fhir_resource, :status, :author, :severity, :detail, 
              :reference, :implicated, :evidence, :mitigations, :patient_id, :patient

  def initialize(fhir_detected_issue, bundle_entries = [])
    @fhir_resource = fhir_detected_issue
    @id = fhir_detected_issue.id
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @author = parse_author(@fhir_resource.author, bundle_entries)
    @status = fhir_detected_issue.status
    @severity = fhir_detected_issue.severity
    @detail = fhir_detected_issue.detail
    @reference = fhir_detected_issue.reference
    @implicated = parse_implicated(@fhir_resource.implicated, bundle_entries)
    @evidence = parse_evidence
    @mitigations = parse_mitigations

    self.class.update(self)
  end

  private

  def read_author(author, bundle_entries)
    resource = get_object_from_bundle(author.reference, bundle_entries)
    resource.resourceType.constantize.new(resource, bundle_entries) unless resource.nil?
  end

  def parse_implicated(implicated, bundle_entries)
    resource = get_object_from_bundle(implicated.reference, bundle_entries)
    resource.resourceType.constantize.new(resource, bundle_entries) unless resource.nil?
  end

  def parse_evidence
    @fhir_resource.evidence.map do |evidence|
      code = evidence.code.coding.first&.code
      display = evidence.code.coding.first&.display

      formatted_evidence = "#{display} (#{code})"
      resource = get_object_from_bundle(evidence.detail, bundle_entries)
      detail = resource.resourceType.constantize.new(resource, bundle_entries) unless resource.nil?
      { code: formatted_evidence, detail: detail }
    end&.compact
  end

  def parse_mitigations
    @fhir_resource.mitigation.map do |mitigation|
      code = mitigation.action.coding.first&.code
      display = mitigation.action.coding.first&.display

      formatted_mitigation = "#{display} (#{code})"
      resource = get_object_from_bundle(mitigation.author, bundle_entries)
      author = resource.resourceType.constantize.new(resource, bundle_entries) unless resource.nil?
      { code: formatted_mitigation, date: mitigation.date, author: author }
    end&.compact
  end
end

