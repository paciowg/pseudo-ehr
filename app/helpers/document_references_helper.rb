# app/helpers/document_references_helper.rb
module DocumentReferencesHelper
  EMPTY_REASON_DISPLAY = {
    'nilknown' => 'No known information available.',
    'notasked' => 'Information not asked or not available.'
  }.freeze

  def extract_composition_title(bundle)
    toc_composition(bundle)&.title.to_s
  end

  def toc_bundle_view_model(bundle)
    composition = toc_composition(bundle)
    return nil if composition.blank?

    {
      title: toc_bundle_title(bundle),
      patient: toc_bundle_subject(bundle),
      author: toc_bundle_author(bundle),
      custodian: toc_bundle_custodian(bundle),
      sections: toc_sections_for_display(bundle)
    }
  end

  def toc_composition(bundle)
    bundle_entries(bundle).find { |entry| entry.resource.is_a?(FHIR::Composition) }&.resource
  end

  def toc_bundle_title(bundle)
    toc_composition(bundle)&.title.to_s
  end

  def toc_bundle_subject(bundle)
    composition = toc_composition(bundle)
    patient = resolve_bundle_reference(bundle, composition&.subject&.reference)
    return nil unless patient.is_a?(FHIR::Patient)

    {
      name: patient_display_name(patient),
      dob: patient.birthDate.presence,
      gender: patient.gender.presence,
      mrn: patient_mrn(patient),
      address: address_text(patient.address&.first),
      telecom: patient_telecom_lines(patient)
    }
  end

  def toc_bundle_author(bundle)
    composition = toc_composition(bundle)
    author = resolve_bundle_reference(bundle, composition&.author&.first&.reference)
    return nil if author.blank?

    case author
    when FHIR::PractitionerRole
      practitioner = resolve_bundle_reference(bundle, author.practitioner&.reference)
      organization = resolve_bundle_reference(bundle, author.organization&.reference)

      {
        name: practitioner_display_name(practitioner).presence || author.practitioner&.display.presence || author.id,
        role: coding_or_text(author.code).presence,
        organization: resource_display_name(organization).presence || author.organization&.display.presence
      }
    when FHIR::Practitioner
      {
        name: practitioner_display_name(author),
        role: nil,
        organization: nil
      }
    when FHIR::Patient
      {
        name: patient_display_name(author),
        role: 'Patient',
        organization: nil
      }
    else
      {
        name: resource_display_name(author),
        role: nil,
        organization: nil
      }
    end
  end

  def toc_bundle_custodian(bundle)
    composition = toc_composition(bundle)
    custodian = resolve_bundle_reference(bundle, composition&.custodian&.reference)
    return nil if custodian.blank?

    {
      name: resource_display_name(custodian),
      address: address_text(custodian.address&.first),
      telecom: telecom_lines(custodian.telecom)
    }
  end

  def toc_bundle_sections(bundle)
    toc_composition(bundle)&.section.to_a
  end

  def toc_sections_for_display(bundle)
    toc_bundle_sections(bundle).map do |section|
      code = section_code(section)
      resources = resolve_section_entry_resources(bundle, section)

      {
        title: section.title.presence || code_display(section.code),
        code: code,
        code_display: code_display(section.code),
        empty_message: section_empty_message(section, resources),
        items: resources.flat_map { |resource| toc_display_entry(resource, bundle, section_code: code) }.compact
      }
    end
  end

  def bundle_entries(bundle)
    bundle&.entry.to_a
  end

  def bundle_resource_index(bundle)
    @bundle_resource_indexes ||= {}
    cache_key = bundle.object_id

    @bundle_resource_indexes[cache_key] ||= begin
      index = {}

      bundle_entries(bundle).each do |entry|
        resource = entry.resource
        next if resource.blank?

        full_url = entry.fullUrl.to_s.presence
        resource_type = resource.resourceType.to_s.presence
        resource_id = resource.id.to_s.presence

        index[full_url] = resource if full_url.present?
        index["#{resource_type}/#{resource_id}"] = resource if resource_type.present? && resource_id.present?
        index[resource_id] = resource if resource_id.present?
      end

      index
    end
  end

  def resolve_bundle_reference(bundle, reference)
    return nil if bundle.blank? || reference.blank?

    index = bundle_resource_index(bundle)
    reference_str = reference.to_s

    index[reference_str] ||
      index[reference_str.split('/').last] ||
      index[reference_str]
  end

  def resolve_section_entry_resources(bundle, section)
    section.entry.to_a.filter_map { |entry_ref| resolve_bundle_reference(bundle, entry_ref.reference) }
  end

  def toc_display_entry(resource, bundle, section_code: nil)
    case resource
    when FHIR::Device
      [display_device(resource)]
    when FHIR::MedicationRequest
      [display_medication_request(resource)]
    when FHIR::MedicationStatement
      [display_medication_statement(resource)]
    when FHIR::Medication
      [display_medication(resource)]
    when FHIR::List
      display_list(resource, bundle)
    when FHIR::CarePlan
      [display_care_plan(resource, bundle)]
    when FHIR::Condition
      [display_condition(resource)]
    when FHIR::AllergyIntolerance
      [display_allergy_intolerance(resource)]
    when FHIR::Observation
      display_observation(resource, bundle, section_code: section_code)
    when FHIR::ServiceRequest
      [display_service_request(resource)]
    when FHIR::DocumentReference
      [display_document_reference(resource)]
    when FHIR::DiagnosticReport
      [display_diagnostic_report(resource)]
    when FHIR::Immunization
      [display_immunization(resource)]
    when FHIR::Encounter
      [display_encounter(resource)]
    when FHIR::Composition
      [display_composition(resource)]
    else
      [display_generic_resource(resource)]
    end
  end

  def section_empty_message(section, resources)
    return nil if resources.present?

    empty_reason_code = section.emptyReason&.coding.to_a&.first&.code.to_s.presence
    EMPTY_REASON_DISPLAY[empty_reason_code] || 'No entries in this section.'
  end

  def display_device(resource)
    {
      heading: resource.deviceName.to_a.find { |name| name.name.present? }&.name.to_s.presence || code_display(resource.type) || resource.id,
      meta: compact_meta(
        "Status: #{resource.status}",
        "Type: #{code_display(resource.type)}",
        "Code: #{first_coding_code(resource.type)}"
      )
    }
  end

  def display_medication_request(resource)
    {
      heading: medication_name(resource),
      meta: compact_meta(
        "Status: #{resource.status}",
        "Intent: #{resource.intent}",
        "Authored: #{display_date(resource.authoredOn)}"
      )
    }
  end

  def display_medication_statement(resource)
    {
      heading: medication_name(resource),
      meta: compact_meta(
        "Status: #{resource.status}",
        "Asserted: #{display_date(resource.dateAsserted)}"
      )
    }
  end

  def display_medication(resource)
    {
      heading: code_display(resource.code) || resource.id,
      meta: compact_meta(
        "Code: #{first_coding_code(resource.code)}"
      )
    }
  end

  def display_list(resource, bundle)
    items = resource.entry.to_a.filter_map do |list_entry|
      entry_resource = resolve_bundle_reference(bundle, list_entry.item&.reference)
      next if entry_resource.blank?

      toc_display_entry(entry_resource, bundle, section_code: '10160-0')
    end.flatten.compact

    [
      {
        heading: resource.title.presence || code_display(resource.code) || 'Medication List',
        meta: compact_meta(
          "Status: #{resource.status}",
          "Mode: #{resource.mode}",
          "Date: #{display_date(resource.date)}",
          "Items: #{resource.entry.to_a.size}"
        ),
        children: items
      }
    ]
  end

  def display_care_plan(resource, bundle)
    goals = resource.goal.to_a.filter_map do |goal_ref|
      goal = resolve_bundle_reference(bundle, goal_ref.reference)
      next if goal.blank?

      goal_text = goal.respond_to?(:description) ? codeable_text(goal.description) : resource_display_name(goal)
      next if goal_text.blank?

      {
        heading: "Goal: #{goal_text}",
        meta: []
      }
    end

    activities = resource.activity.to_a.map do |activity|
      activity_text = activity.detail&.description.presence || code_display(activity.detail&.code) || activity.reference&.reference
      next if activity_text.blank?

      {
        heading: "Activity: #{activity_text}",
        meta: []
      }
    end.compact

    {
      heading: resource.title.presence || 'Care Plan',
      meta: compact_meta(
        "Status: #{resource.status}",
        "Intent: #{resource.intent}",
        "Created: #{display_date(resource.created)}"
      ),
      children: goals + activities
    }
  end

  def display_condition(resource)
    {
      heading: code_display(resource.code) || resource.id,
      meta: compact_meta(
        "Clinical status: #{first_coding_code(resource.clinicalStatus)}",
        "Verification: #{first_coding_code(resource.verificationStatus)}",
        "Onset: #{display_date(resource.onsetDateTime)}",
        "Recorded: #{display_date(resource.recordedDate)}",
        "Body site: #{code_display(resource.bodySite.to_a.first)}",
        "Note: #{resource.note.to_a.first&.text}"
      )
    }
  end

  def display_allergy_intolerance(resource)
    {
      heading: code_display(resource.code) || resource.id,
      meta: compact_meta(
        "Clinical status: #{first_coding_code(resource.clinicalStatus)}",
        "Verification: #{first_coding_code(resource.verificationStatus)}",
        "Criticality: #{resource.criticality}",
        "Category: #{resource.category.to_a.join(', ')}"
      )
    }
  end

  def display_observation(resource, bundle, section_code: nil)
    panel_members = if expand_observation_members?(resource, section_code)
                      resource.hasMember.to_a.filter_map do |member_ref|
                        member = resolve_bundle_reference(bundle, member_ref.reference)
                        next if member.blank?

                        {
                          heading: code_display(member.code) || member.id,
                          meta: compact_meta(
                            "Date: #{display_date(observation_effective_date(member))}",
                            "Value: #{observation_value_text(member)}",
                            "Interpretation: #{interpretation_text(member)}"
                          )
                        }
                      end
                    else
                      []
                    end

    [
      {
        heading: code_display(resource.code) || resource.id,
        meta: compact_meta(
          "Date: #{display_date(observation_effective_date(resource))}",
          "Value: #{observation_value_text(resource)}",
          "Interpretation: #{interpretation_text(resource)}"
        ),
        children: panel_members
      }
    ]
  end

  def display_service_request(resource)
    {
      heading: code_display(resource.code) || resource.id,
      meta: compact_meta(
        "Status: #{resource.status}",
        "Intent: #{resource.intent}",
        "Occurrence: #{display_date(resource.occurrenceDateTime || resource.occurrencePeriod&.start)}",
        "Authored: #{display_date(resource.authoredOn)}"
      )
    }
  end

  def display_document_reference(resource)
    {
      heading: resource.description.presence || code_display(resource.type) || resource.id,
      meta: compact_meta(
        "Status: #{resource.status}",
        "Date: #{display_date(resource.date)}",
        "Type: #{code_display(resource.type)}"
      )
    }
  end

  def display_diagnostic_report(resource)
    {
      heading: code_display(resource.code) || resource.id,
      meta: compact_meta(
        "Status: #{resource.status}",
        "Date: #{display_date(resource.effectiveDateTime || resource.issued)}",
        "Category: #{code_display(resource.category.to_a.first)}"
      )
    }
  end

  def display_immunization(resource)
    {
      heading: code_display(resource.vaccineCode) || resource.id,
      meta: compact_meta(
        "Status: #{resource.status}",
        "Date: #{display_date(resource.occurrenceDateTime || resource.occurrenceString)}"
      )
    }
  end

  def display_encounter(resource)
    {
      heading: code_display(resource.type.to_a.first) || resource.id,
      meta: compact_meta(
        "Status: #{resource.status}",
        "Class: #{resource.class_fhir&.code}",
        "Start: #{display_date(resource.period&.start)}",
        "End: #{display_date(resource.period&.end)}"
      )
    }
  end

  def display_composition(resource)
    {
      heading: resource.title.presence || resource.id,
      meta: compact_meta(
        "Date: #{display_date(resource.date)}",
        "Type: #{code_display(resource.type)}"
      )
    }
  end

  def display_generic_resource(resource)
    {
      heading: resource_display_name(resource),
      meta: compact_meta(
        "Resource type: #{resource.resourceType}",
        "ID: #{resource.id}"
      )
    }
  end

  def expand_observation_members?(resource, section_code)
    section_code == '8716-3' && resource.hasMember.to_a.present?
  end

  def section_code(section)
    section.code&.coding.to_a&.first&.code.to_s.presence
  end

  def patient_display_name(patient)
    patient.name.to_a.find { |name| name.text.present? }&.text.to_s.presence ||
      begin
        name = patient.name.to_a.first
        [name&.family, name&.given.to_a].flatten.compact.join(', ').presence
      end ||
      patient.id
  end

  def practitioner_display_name(practitioner)
    return nil if practitioner.blank?

    practitioner.name.to_a.find { |name| name.text.present? }&.text.to_s.presence ||
      begin
        name = practitioner.name.to_a.first
        [name&.given.to_a.join(' '), name&.family].compact.join(' ').presence
      end ||
      practitioner.id
  end

  def patient_mrn(patient)
    patient.identifier.to_a.find do |identifier|
      identifier.type&.coding.to_a.any? { |coding| coding.code == 'MR' }
    end&.value.to_s.presence
  end

  def resource_display_name(resource)
    return nil if resource.blank?

    case resource
    when FHIR::Patient
      patient_display_name(resource)
    when FHIR::Practitioner
      practitioner_display_name(resource)
    when FHIR::Organization, FHIR::Location
      resource.name.to_s.presence || resource.id
    else
      resource.respond_to?(:title) && resource.title.present? ? resource.title.to_s : resource.id
    end
  end

  def medication_name(resource)
    code_display(resource.medicationCodeableConcept) ||
      resolve_bundle_reference(nil, nil) ||
      resource.id
  end

  def code_display(codeable)
    return nil if codeable.blank?

    if codeable.respond_to?(:text) && codeable.text.present?
      codeable.text.to_s
    elsif codeable.respond_to?(:coding)
      coding = codeable.coding.to_a.find { |c| c.display.present? } || codeable.coding.to_a.first
      coding&.display.to_s.presence || coding&.code.to_s.presence
    elsif codeable.respond_to?(:display)
      codeable.display.to_s.presence
    end
  end

  def codeable_text(codeable)
    code_display(codeable)
  end

  def first_coding_code(codeable)
    return nil if codeable.blank?

    if codeable.respond_to?(:coding)
      codeable.coding.to_a.first&.code.to_s.presence
    end
  end

  def observation_effective_date(resource)
    resource.effectiveDateTime || resource.effectivePeriod&.start || resource.issued
  end

  def observation_value_text(resource)
    return resource.valueQuantity.value.to_s + " #{resource.valueQuantity.unit}".strip if resource.respond_to?(:valueQuantity) && resource.valueQuantity.present? && resource.valueQuantity.value.present?
    return code_display(resource.valueCodeableConcept) if resource.respond_to?(:valueCodeableConcept) && resource.valueCodeableConcept.present?
    return resource.valueString.to_s if resource.respond_to?(:valueString) && resource.valueString.present?
    return resource.valueInteger.to_s if resource.respond_to?(:valueInteger) && resource.valueInteger.present?
    return resource.valueDecimal.to_s if resource.respond_to?(:valueDecimal) && resource.valueDecimal.present?

    component_values = resource.component.to_a.map do |component|
      next if component.blank?

      label = code_display(component.code)
      value =
        if component.valueQuantity.present?
          "#{component.valueQuantity.value} #{component.valueQuantity.unit}".strip
        elsif component.valueCodeableConcept.present?
          code_display(component.valueCodeableConcept)
        end

      [label, value].compact.join(': ')
    end.compact

    component_values.join(', ').presence
  end

  def interpretation_text(resource)
    code_display(resource.interpretation.to_a.first)
  end

  def address_text(address)
    return nil if address.blank?

    address.text.to_s.presence ||
      [
        address.line.to_a.join(', ').presence,
        address.city.presence,
        address.state.presence,
        address.postalCode.presence,
        address.country.presence
      ].compact.join(', ').presence
  end

  def telecom_lines(telecoms)
    telecoms.to_a.map do |telecom|
      next if telecom.value.blank?

      [telecom.system.presence&.capitalize, telecom.value].compact.join(': ')
    end.compact
  end

  def patient_telecom_lines(patient)
    telecom_lines(patient.telecom)
  end

  def display_date(value)
    return nil if value.blank?

    value.to_s
  end

  def compact_meta(*items)
    items.flatten.compact.reject(&:blank?)
  end

  def coding_or_text(codeables)
    Array(codeables).flat_map do |codeable|
      code_display(codeable)
    end.compact.join(', ').presence
  end
end
