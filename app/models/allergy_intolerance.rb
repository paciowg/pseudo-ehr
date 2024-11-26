# AllergyIntolerance Model
class AllergyIntolerance < Resource
  attr_reader :id, :clinical_status, :verification_status, :category, :criticality,
              :code, :asserter, :last_occurence, :reactions, :fhir_resource

  def initialize(fhir_allergy_intolerance, bundle_entries)
    @fhir_resource = fhir_allergy_intolerance
    @id = fhir_allergy_intolerance.id
    @clinical_status = fhir_allergy_intolerance.clinicalStatus.coding.first&.code&.capitalize
    @verification_status = fhir_allergy_intolerance.verificationStatus.coding.first&.code&.capitalize
    @category = fhir_allergy_intolerance.category.join(', ')
    @criticality = fhir_allergy_intolerance.criticality&.capitalize
    @code = retrieve_code
    @asserter = retrieve_asserter(bundle_entries)
    @last_occurence = fhir_allergy_intolerance.lastOccurrence
    @reactions = retrieve_reactions
  end

  private

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

    case resource_type
    when 'Practitioner', 'Patient', 'RelatedPerson'
      format_name(asserter_resource.name) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    when 'PractitionerRole'
      name = asserter_resource.practitioner.display
      return name if name

      practioner_id = asserter_resource.practitioner.reference.split('/').last
      practitioner = bundle_entries.find { |res| res.resourceType == 'Practitioner' && res.id == practioner_id }
      format_name(practitioner.name) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    else
      '--'
    end
  end

  def retrieve_reactions
    @fhir_resource.reaction.map do |fhir_reaction|
      {
        substance: coding_string(fhir_reaction.substance.coding),
        manifestation: fhir_reaction.manifestation.map { |m| coding_string(m.coding) }.join(', ')
      }
    end
  end
end
