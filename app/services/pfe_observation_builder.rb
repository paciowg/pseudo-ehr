class PfeObservationBuilder
  US_CORE_CATEGORY_URL = 'http://hl7.org/fhir/us/core/CodeSystem/us-core-category'.freeze
  SURVEY_CATEGORY_URL = 'http://hl7.org/fhir/us/pacio-pfe/CodeSystem/pfe-survey-category-cs'.freeze
  PFE_DOMAIN_CATEGORY_URL = 'http://hl7.org/fhir/us/pacio-pfe/CodeSystem/pfe-category-cs'.freeze

  EXT_EVENT_LOCATION = 'http://hl7.org/fhir/StructureDefinition/event-location'.freeze
  EXT_DEVICE_USE = 'http://hl7.org/fhir/us/pacio-pfe/StructureDefinition/device-patient-used'.freeze

  PFE_SINGLE_OBS_PROFILE = 'http://hl7.org/fhir/us/pacio-pfe/StructureDefinition/pfe-observation-single'.freeze

  def initialize(qr, questionnaire) # rubocop:disable Naming/MethodParameterName
    @qr = qr
    @questionnaire = questionnaire
    @link_id_map = extract_link_id_map(questionnaire)
    @domain_code = extract_domain_code
  end

  def build
    return [] if @qr.item.blank?

    extract_observations(@qr.item)
  end

  private

  # Recursively extract observations from all leaf items
  def extract_observations(items)
    items.flat_map do |item|
      if item.item.present?
        extract_observations(item.item)
      else
        build_observations(item)
      end
    end.compact
  end

  # Build one observation per answer
  def build_observations(item)
    return if item&.answer.blank?

    item.answer.map do |answer|
      obs = FHIR::Observation.new(
        id: SecureRandom.uuid,
        status: 'final',
        category: build_category_slice,
        code: { coding: @link_id_map[item.linkId] || [] },
        subject: @qr.subject,
        effectiveDateTime: @qr.authored,
        performer: Array(@qr.author).compact,
        derivedFrom: [{ reference: "QuestionnaireResponse/#{@qr.id}" }],
        meta: { profile: [PFE_SINGLE_OBS_PROFILE] }
      )

      set_answer_value(obs, answer)
      add_extensions(obs)
      obs
    end
  end

  # Set the correct value[x] based on answer type
  def set_answer_value(obs, answer)
    if answer.valueCoding.present?
      obs.valueCodeableConcept = FHIR::CodeableConcept.new(coding: [answer.valueCoding])
    elsif answer.valueString.present?
      obs.valueString = answer.valueString
    elsif answer.valueInteger.present?
      obs.valueInteger = answer.valueInteger
    elsif answer.valueDate.present?
      obs.valueDateTime = answer.valueDate
    elsif answer.valueDateTime.present?
      obs.valueDateTime = answer.valueDateTime
    elsif answer.valueBoolean.present?
      obs.valueBoolean = answer.valueBoolean
    elsif answer.valueDecimal.present?
      obs.valueDecimal = answer.valueDecimal
    elsif answer.valueTime.present?
      obs.valueTime = answer.valueTime
    end
  end

  # Add extensions if available (event-location and device-use)
  def add_extensions(obs)
    obs.extension ||= []

    author_ref = @qr.author&.reference
    return if author_ref.blank?

    # Add device-use extension if author is a Device
    return unless author_ref.start_with?('Device/')

    obs.extension << {
      url: EXT_DEVICE_USE,
      valueReference: { reference: author_ref }
    }

    # TODO: determine how to dynamically extract location
    # Add event-location extension
    # obs.extension << {
    #   url: EXT_EVENT_LOCATION,
    #   valueReference: author_ref
    # }
  end

  # Extract the PFEDomain code from the Questionnaire.code list
  def extract_domain_code
    domain_code = @questionnaire.code&.find do |coding|
      coding.system == PFE_DOMAIN_CATEGORY_URL
    end

    domain_code&.code || 'unknown'
  end

  # Create the required category slices
  def build_category_slice
    [
      FHIR::CodeableConcept.new(coding: [
                                  { system: US_CORE_CATEGORY_URL, code: ' functional-status' }
                                ]),
      FHIR::CodeableConcept.new(coding: [
                                  { system: SURVEY_CATEGORY_URL, code: 'survey' }
                                ]),
      FHIR::CodeableConcept.new(coding: [
                                  { system: PFE_DOMAIN_CATEGORY_URL, code: @domain_code }
                                ])
    ]
  end

  # Extract LOINC codes from Questionnaire items
  def extract_link_id_map(questionnaire)
    map = {}
    traverse_items(questionnaire.item, map)
    map
  end

  def traverse_items(items, map)
    items.each do |item|
      if item.item.present?
        traverse_items(item.item, map)
      else
        map[item.linkId] = item.code
      end
    end
  end
end
