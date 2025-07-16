class PfeObservationBuilder
  US_CORE_CATEGORY_URL = 'http://hl7.org/fhir/us/core/CodeSystem/us-core-category'.freeze
  SURVEY_CATEGORY_URL = 'http://hl7.org/fhir/us/pacio-pfe/CodeSystem/pfe-survey-category-cs'.freeze
  PFE_DOMAIN_CATEGORY_URL = 'http://hl7.org/fhir/us/pacio-pfe/CodeSystem/pfe-category-cs'.freeze

  EXT_EVENT_LOCATION = 'http://hl7.org/fhir/StructureDefinition/event-location'.freeze
  EXT_DEVICE_USE = 'http://hl7.org/fhir/us/pacio-pfe/StructureDefinition/device-patient-used'.freeze

  PFE_SINGLE_OBS_PROFILE = 'http://hl7.org/fhir/us/pacio-pfe/StructureDefinition/pfe-observation-single'.freeze
  PFE_COLLECTION_PROFILE = 'http://hl7.org/fhir/us/pacio-pfe/StructureDefinition/pfe-collection'.freeze

  def initialize(qr, questionnaire) # rubocop:disable Naming/MethodParameterName
    @qr = qr
    @questionnaire = questionnaire
    @link_id_map = extract_link_id_map(questionnaire)
  end

  def build
    return [] if @qr.item.blank?

    collection = build_collection
    observations = extract_observations(@qr.item, collection)

    collection.category = PfeCategoryCodeExtractor.collection_category_slice(observations)
    collection.category.reject! { |cat| cat.coding&.any? { |c| c.code == 'unknown' } }

    observations << collection
  end

  private

  # Recursively extract observations from all leaf items
  def extract_observations(items, collection)
    items.flat_map do |item|
      if item.item.present?
        extract_observations(item.item, collection)
      else
        build_observations(item, collection)
      end
    end.compact.uniq
  end

  # Build collection for grouping answer observations
  def build_collection
    obs = FHIR::Observation.new(
      id: "#{@qr.id}-#{SecureRandom.hex(4)}", # SecureRandom.uuid
      status: 'final',
      code: { coding: @questionnaire.code },
      category: PfeCategoryCodeExtractor.extract(@questionnaire.code.first&.code),
      subject: @qr.subject,
      effectiveDateTime: @qr.authored,
      performer: Array(@qr.author).compact,
      derivedFrom: [{ reference: "QuestionnaireResponse/#{@qr.id}" }],
      meta: { profile: [PFE_COLLECTION_PROFILE] }
    )

    add_extensions(obs)
    obs
  end

  # Build one observation per item.
  # TODO: handle parsing obs value for item with multiple answers
  def build_observations(item, collection)
    return if item&.answer.blank?

    item_link_id = item.linkId.to_s.delete_prefix('/')
    answer = item.answer.first
    obs = FHIR::Observation.new(
      id: "#{@qr.id}-#{item_link_id&.camelize}", # SecureRandom.uuid,
      status: 'final',
      category: PfeCategoryCodeExtractor.extract(item_link_id),
      code: { coding: @link_id_map[item_link_id] || default_obs_coding(item) },
      subject: @qr.subject,
      effectiveDateTime: @qr.authored,
      performer: Array(@qr.author).compact,
      derivedFrom: [{ reference: "QuestionnaireResponse/#{@qr.id}" }],
      meta: { profile: [PFE_SINGLE_OBS_PROFILE] }
    )

    set_answer_value(obs, answer, item_link_id)
    add_extensions(obs)

    if collection.code&.coding.blank?
      collection.code = FHIR::CodeableConcept.new(coding: @link_id_map[item_link_id] || default_obs_coding(item))
    end

    collection.hasMember << { reference: "Observation/#{obs.id}" }
    obs
  end

  def default_obs_coding(item)
    return [] if item.blank?

    [
      {
        system: 'http://loinc.org', # default to loinc
        code: item.linkId&.delete_prefix('/'),
        display: item.text
      }
    ]
  end

  # Set the correct value[x] based on answer type
  # TODO: handle parsing obs value for item with multiple answers
  def set_answer_value(obs, answer, link_id)
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
      obs.valueQuantity = build_quantity(answer.valueDecimal, link_id)
    elsif answer.valueTime.present?
      obs.valueTime = answer.valueTime
    end
  end

  def build_quantity(value, link_id)
    unit_coding = find_unit_coding_for_link_id(link_id)

    if unit_coding
      FHIR::Quantity.new(
        value: value,
        unit: unit_coding.display,
        code: unit_coding.code,
        system: unit_coding.system
      )
    else
      FHIR::Quantity.new(value: value)
    end
  end

  def find_unit_coding_for_link_id(link_id)
    find_unit_in_items(@questionnaire.item, link_id)
  end

  def find_unit_in_items(items, link_id)
    items.each do |item|
      if item.linkId.to_s.delete_prefix('/') == link_id&.delete_prefix('/')
        ext = item.extension&.find { |e| e.url == 'http://hl7.org/fhir/StructureDefinition/questionnaire-unit' }
        return ext.valueCoding if ext&.valueCoding.present?
      elsif item.item.present?
        found_unit = find_unit_in_items(item.item, link_id)
        return found_unit if found_unit.present?
      end
    end
    nil
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

  # Extract LOINC codes from Questionnaire items
  def extract_link_id_map(questionnaire)
    map = {}
    traverse_items(questionnaire.item, map)
    map
  end

  def traverse_items(items, map)
    items.each do |item|
      map[item.linkId.to_s.delete_prefix('/')] = item.code.presence || default_obs_coding(item)

      traverse_items(item.item, map) if item.item.present?
    end
  end
end
