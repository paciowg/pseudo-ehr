# Condition Model
class Condition < Resource
  attr_reader :id, :clinical_status, :verification_status, :category,
              :code, :onset_date_time, :asserted_date, :recorded_date,
              :asserter, :evidences, :note, :body_site, :fhir_resource,
              :patient_id, :patient

  def initialize(fhir_condition, bundle_entries = [])
    @fhir_resource = fhir_condition
    @id = fhir_condition.id
    @patient_id = fhir_condition.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @clinical_status = fhir_condition.clinicalStatus.coding.first&.code&.capitalize
    @verification_status = fhir_condition.verificationStatus.coding.first&.code&.capitalize
    @category = retrieve_categories
    @code = retrieve_code
    @onset_date_time = fhir_condition.try(:onsetDateTime)
    @asserted_date = fhir_condition.try(:assertedDate)
    @recorded_date = fhir_condition.try(:recordedDate)
    @asserter = parse_provider_name(@fhir_resource.asserter, bundle_entries)
    @evidences = retrieve_evidences(bundle_entries)
    @body_site = fhir_condition.bodySite&.map { |c| coding_string(c.coding) }&.join(', ')
    @note = fhir_condition.try(:note)&.first&.text || '--'

    self.class.update(self)
  end

  def type
    if @category&.downcase&.include?('encounter-diagnosis')
      'encounter-diagnosis'
    elsif @category&.downcase&.include?('problem-list-item') || @category&.downcase&.include?('health-concern')
      'problem-list-item'
    else
      'other'
    end
  end

  def onset
    parse_date(@onset_date_time)
  end

  def recorded
    parse_date(@recorded_date)
  end

  def asserted
    parse_date(@asserted_date)
  end

  private

  def retrieve_categories
    @fhir_resource.category.map do |cat|
      code = cat.coding.first&.code
      display = cat.coding.first&.display

      formatted_cat = "#{display} (#{code})"
      formatted_cat.strip.start_with?('(') ? formatted_cat.strip.delete_prefix('(').delete_suffix(')') : formatted_cat
    end.join(', ')
  end

  def retrieve_code
    coding = @fhir_resource.code.coding.first
    code = coding&.code
    display = coding&.display

    formatted_code = "#{display} (#{code})"
    formatted_code.strip.start_with?('(') ? formatted_code.strip.delete_prefix('(').delete_suffix(')') : formatted_code
  end

  def retrieve_evidences(bundle_entries)
    @fhir_resource.evidence.map(&:detail).flatten.map do |item|
      resource_type, id = item.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == id }
      next unless resource

      case resource_type
      when 'Condition'
        Condition.new(resource, bundle_entries).code
      when 'Observation'
        Observation.new(resource, bundle_entries).code
      else
        next
      end
    end.compact
  end
end
