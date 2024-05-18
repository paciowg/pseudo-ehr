# frozen_string_literal: true

# Condition Model
class Condition < Resource
  attr_reader :id, :clinical_status, :verification_status, :category,
              :code, :onset_date_time, :asserted_date, :recorded_date,
              :asserter, :evidences, :note, :body_site, :fhir_resource

  def initialize(fhir_condition, bundle_entries)
    @fhir_resource = fhir_condition
    @id = fhir_condition.id
    @clinical_status = fhir_condition.clinicalStatus.coding.first&.code&.capitalize
    @verification_status = fhir_condition.verificationStatus.coding.first&.code&.capitalize
    @category = retrieve_categories
    @code = retrieve_code
    @onset_date_time = fhir_condition.try(:onsetDateTime)
    @asserted_date = fhir_condition.try(:assertedDate)
    @recorded_date = fhir_condition.try(:recordedDate)
    @asserter = retrieve_asserter(bundle_entries)
    @evidences = retrieve_evidences(fhir_condition.subject)
    @body_site = fhir_condition.bodySite&.map { |c| coding_string(c.coding) }&.join(', ')
    @note = fhir_condition.try(:note)&.first&.text || '--'
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

  def retrieve_asserter(bundle_entries)
    asserter_display = @fhir_resource.asserter&.display
    return asserter_display if asserter_display.present?

    asserter_ref = @fhir_resource.asserter&.reference
    return '--' if asserter_ref.blank?

    resource_type, id = asserter_ref.split('/')

    asserter_resource = bundle_entries.find { |resource| resource.resourceType == resource_type && resource.id == id }
    return '--' if asserter_resource.blank?

    name = '--'
    if resource_type == 'Practitioner'
      format_name(asserter_resource.name) => { first_name:, last_name: }
      name = "#{first_name} #{last_name}"
    elsif resource_type == 'PractitionerRole'
      name = asserter_resource.practitioner&.display || '--'
    end
    name
  end

  def retrieve_evidences(patient_ref)
    patient_id = patient_ref.reference.split('/').last
    detail_refs = @fhir_resource.evidence.map(&:detail).flatten.map(&:reference).compact

    detail_refs.map do |elmt|
      resource_type, id = elmt.split('/')
      path = "/patients/#{patient_id}/#{resource_type.downcase}s/#{id}"
      { name: elmt, path: }
    end
  end
end
