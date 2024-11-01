# Composition Model
class Composition < Resource
  include ActiveModel::Model
  include ActiveModel::Serializers::JSON

  attr_reader :id, :identifier, :status, :type, :category, :date, :author, :title, :custodian,
              :subject, :section

  #-----------------------------------------------------------------------------
  # TODO: Get api keys to read code values from https://cts.nlm.nih.gov/fhir/login.html
  def initialize(fhir_composition, fhir_bundle)
    @id = fhir_composition.id
    @identifier = fhir_composition.identifier&.value || '--'
    @status = fhir_composition.status
    @type = coding_string(fhir_composition.type&.coding)
    @category = category_string(fhir_composition.category)
    @date = parse_date(fhir_composition.date)
    @author = retrieve_author(fhir_composition.author, fhir_bundle)
    @title = fhir_composition.title
    @custodian = get_custodian(fhir_composition.custodian, fhir_bundle)
    fhir_patient = get_object_from_bundle(fhir_composition.subject, fhir_bundle)
    @fhir_bundle = fhir_bundle
    @subject = Patient.new(fhir_patient) if fhir_patient
    fill_sections(fhir_composition.section, fhir_bundle)
  end

  private

  def retrieve_author(fhir_author, fhir_bundle)
    author = fhir_author.first
    return '--' unless author
    return author.display if author.display

    author_resource =  get_object_from_bundle(author, fhir_bundle)
    return '--' unless author_resource

    case author_resource.resourceType
    when 'Practitioner', 'Patient', 'RelatedPerson'
      format_name(author_resource.name) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    when 'Organization'
      author_resource.name
    when 'PractitionerRole'
      name = author_resource.practitioner.display
      return name if name

      practioner_id = author_resource.practitioner.reference.split('/').last
      practitioner = get_object_from_bundle(FHIR::Reference.new(reference: "Practitioner/#{practioner_id}"),
                                            fhir_bundle)

      return '--' unless practitioner

      format_name(practitioner.name) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    end
  end

  def fill_sections(section_list, fhir_bundle)
    @section = []
    return if fhir_bundle.blank?

    section_list.each do |section|
      section_objects = {
        'text' => section&.text&.div,
        'title' => section&.title || '--',
        'objects' => []
      }
      clause_ext = section.extension.find { |ext| ext.url == 'http://hl7.org/fhir/us/pacio-adi/StructureDefinition/padi-clause-extension' }
      clause = clause_ext&.extension&.find { |ext| ext.url == 'Clause' }&.valueMarkdown
      section_objects['clause'] = clause
      section_objects['code'] = coding_string(section.code&.coding) if section.code&.coding.present?

      section.entry&.each do |current_entry|
        resource_type, resource_id = extract_resource_data(current_entry)

        next unless resource_type && resource_id

        temp_resource = get_object_from_bundle(current_entry, fhir_bundle)

        section_objects['objects'].push(build_resource_hash(resource_type, temp_resource))
        section_objects['objects'].uniq!
      end

      @section.push(section_objects)
    end
  end

  def build_resource_hash(resource_type, resource)
    case resource_type
    when 'ServiceRequest'
      build_service_request_hash(resource)
    when 'Goal'
      build_goal_hash(resource)
    when 'Observation'
      build_observation_hash(resource)
    when 'RelatedPerson'
      build_related_person_hash(resource)
    when 'Consent'
      build_consent_hash(resource)
    when 'CarePlan'
      build_careplan_hash(resource)
    when 'AllergyIntolerance'
      build_allergy_intolerance_hash(resource)
    when 'Condition'
      build_condition_hash(resource)
    else
      Rails.logger.debug { "error unexpected type: #{resource_type}" }
      {}
    end
  rescue StandardError => e
    Rails.logger.debug { "oops #{e.message}" }
    {}
  end

  def build_service_request_hash(resource)
    {
      resource_type: 'ServiceRequest',
      category: category_string(resource&.category),
      request_code: resource&.code&.coding&.first&.code || '--',
      request: coding_string(resource&.code&.coding),
      request_text: resource&.code&.text || '--',
      status: resource.status || '--',
      resource: ServiceRequest.new(resource, @fhir_bundle)
    }
  end

  def build_goal_hash(resource)
    {
      resource_type: 'Goal',
      type: category_string(resource&.category),
      preference: resource&.description&.text || '--'
    }
  end

  def build_observation_hash(resource)
    hash = {
      resource_type: 'Observation',
      type: coding_string(resource&.code&.coding),
      type_text: resource&.code&.text || '--',
      preference: resource&.valueString || '--',
      preference_text: '--',
      resource: Observation.new(resource, @fhir_bundle)
    }
    unless resource&.valueCodeableConcept.nil?
      hash[:preference] = coding_string(resource&.valueCodeableConcept&.coding)
      hash[:preference_text] = resource&.code&.text || '--'
    end
    hash
  end

  def build_related_person_hash(resource)
    name = format_name(resource&.name)
    full_name = "#{name[:first_name]} #{name[:last_name]}"
    no_name = full_name == 'XXXXXX XXXXXX'
    full_name = @subject.name if no_name
    {
      resource_type: 'RelatedPerson',
      name: full_name,
      phone: no_name ? @subject.phone : format_phone(resource&.telecom),
      email: no_name ? @subject.email : format_email(resource&.telecom),
      relationship: category_string(resource&.relationship)
    }
  end

  def build_consent_hash(resource)
    {
      resource_type: 'Consent',
      action: category_string(resource&.provision&.action),
      scope: coding_string(resource&.scope&.coding)
    }
  end

  def build_careplan_hash(resource)
    careplan_goals_ref = resource&.goal
    careplan_goal_resources = careplan_goals_ref&.map { |ref| get_object_from_bundle(ref, @fhir_bundle) }
                                                &.map { |res| build_goal_hash(res) }

    {
      resource_type: 'CarePlan',
      title: resource&.title,
      goals: careplan_goal_resources || [],
      resource: CarePlan.new(resource, @fhir_bundle)
    }
  end

  def build_allergy_intolerance_hash(resource)
    {
      resource_type: resource.resourceType,
      resource: AllergyIntolerance.new(resource, @fhir_bundle)
    }
  end

  def build_condition_hash(resource)
    {
      resource_type: resource.resourceType,
      resource: Condition.new(resource, @fhir_bundle)
    }
  end

  #-----------------------------------------------------------------------------
end
# rubocop:enable Metrics/ClassLength
