# Composition Model
class Composition < Resource
  include ActiveModel::Model
  include ActiveModel::Serializers::JSON

  attr_reader :id, :identifier, :status, :type, :category, :date, :author, :title, :custodian,
              :subject, :sections, :fhir_resource, :patient_id, :patient, :fhir_bundle

  #-----------------------------------------------------------------------------
  # TODO: Get api keys to read code values from https://cts.nlm.nih.gov/fhir/login.html
  def initialize(fhir_composition, fhir_bundle = [])
    @id = fhir_composition.id
    @fhir_resource = fhir_composition
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @identifier = fhir_composition.identifier&.value || '--'
    @status = fhir_composition.status
    @type = coding_string(fhir_composition.type&.coding)
    @category = category_string(fhir_composition.category)
    @date = parse_date(fhir_composition.date)
    @author = retrieve_author(fhir_composition.author, fhir_bundle)
    @title = fhir_composition.title
    @custodian = get_custodian(fhir_composition.custodian, fhir_bundle)
    @fhir_bundle = fhir_bundle
    @subject = @patient
    fill_sections(fhir_composition.section, fhir_bundle)

    self.class.update(self)
  end

  class << self
    def tocs_by_patient(patient_id)
      filter_by_patient_id(patient_id).select { |c| c.category.include?('18761-7') }
    end
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
    @sections = []
    return if fhir_bundle.blank?

    section_list.each do |section|
      section_objects = {
        'text' => section&.text&.div,
        'title' => section&.title || (section.entry.present? ? 'Untitled Section' : '--'),
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

      @sections.push(section_objects)
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
    when 'MedicationRequest'
      build_medication_requests_hash(resource)
    when 'List'
      build_medication_list_hash(resource)
    when 'MedicationStatement'
      build_medication_statement_hash(resource)
    when 'MedicationAdministration'
      build_medication_administration_hash(resource)
    when 'Composition'
      build_composition_hash(resource)
    when 'Encounter'
      build_encounter_hash(resource)
    when 'Immunization'
      build_immunization_hash(resource)
    when 'DiagnosticReport'
      build_diagnostic_report_hash(resource)
    when 'DocumentReference'
      build_document_reference_hash(resource)
    when 'Device'
      build_device_hash(resource)
    when 'Procedure'
      build_procedure_hash(resource)
    when 'ImmunizationRecommendation'
      build_immunization_report_hash(resource)
    when 'QuestionnaireResponse'
      build_questionnaire_reponse_hash(resource)
    else
      Rails.logger.debug { "error unexpected type: #{resource_type}" }
      {}
    end
  rescue StandardError => e
    Rails.logger.debug { "oops #{e.message}" }
    {}
  end

  def build_questionnaire_reponse_hash(resource)
    model_res = QuestionnaireResponse.find(resource.id)
    model_res ||= QuestionnaireResponse.new(resource, @fhir_bundle)
    {
      resource_type: 'QuestionnaireResponse',
      resource: model_res
    }
  end

  def build_medication_list_hash(resource)
    model_res = MedicationList.find(resource.id)
    model_res ||= MedicationList.new(resource, @fhir_bundle)
    {
      resource_type: 'MedicationList',
      resource: model_res
    }
  end

  def build_medication_requests_hash(resource)
    model_res = MedicationRequest.find(resource.id)
    model_res ||= MedicationRequest.new(resource, @fhir_bundle)
    {
      resource_type: 'MedicationRequest',
      resource: model_res
    }
  end

  def build_medication_statement_hash(resource)
    model_res = MedicationStatement.find(resource.id)
    model_res ||= MedicationStatement.new(resource, @fhir_bundle)
    {
      resource_type: 'MedicationStatement',
      resource: model_res
    }
  end

  def build_medication_administration_hash(resource)
    model_res = MedicationAdministration.find(resource.id)
    model_res ||= MedicationAdministration.new(resource, @fhir_bundle)
    {
      resource_type: 'MedicationAdministration',
      resource: model_res
    }
  end

  def build_service_request_hash(resource)
    model_res = ServiceRequest.find(resource.id)
    model_res ||= ServiceRequest.new(resource, @fhir_bundle)
    {
      resource_type: 'ServiceRequest',
      category: category_string(resource&.category),
      request_code: resource&.code&.coding&.first&.code || '--',
      request: coding_string(resource&.code&.coding),
      request_text: resource&.code&.text || '--',
      status: resource.status || '--',
      resource: model_res
    }
  end

  def build_goal_hash(resource)
    model_res = Goal.find(resource.id)
    model_res ||= Goal.new(resource, @fhir_bundle)
    {
      resource_type: 'Goal',
      type: category_string(resource&.category),
      preference: resource&.description&.text || '--',
      resource: model_res
    }
  end

  def build_observation_hash(resource)
    model_res = Observation.find(resource.id)
    model_res ||= Observation.new(resource, @fhir_bundle)
    hash = {
      resource_type: 'Observation',
      type: coding_string(resource&.code&.coding),
      type_text: resource&.code&.text || '--',
      preference: resource&.valueString || '--',
      preference_text: '--',
      resource: model_res
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
    model_res = RelatedPerson.find(resource.id)
    model_res ||= RelatedPerson.new(resource, @fhir_bundle)
    {
      resource_type: 'RelatedPerson',
      name: full_name,
      phone: no_name ? @subject.phone : format_phone(resource&.telecom),
      email: no_name ? @subject.email : format_email(resource&.telecom),
      relationship: category_string(resource&.relationship),
      resource: model_res
    }
  end

  def build_consent_hash(resource)
    model_res = Consent.find(resource.id)
    model_res ||= Consent.new(resource, @fhir_bundle)
    {
      resource_type: 'Consent',
      action: category_string(resource&.provision&.action),
      scope: coding_string(resource&.scope&.coding),
      resource: model_res
    }
  end

  def build_careplan_hash(resource)
    careplan_goals_ref = resource&.goal
    careplan_goal_resources = careplan_goals_ref&.map { |ref| get_object_from_bundle(ref, @fhir_bundle) }
                                                &.map { |res| build_goal_hash(res) }

    model_res = CarePlan.find(resource.id)
    model_res ||= CarePlan.new(resource, @fhir_bundle)
    {
      resource_type: 'CarePlan',
      title: resource&.title,
      goals: careplan_goal_resources || [],
      resource: model_res
    }
  end

  def build_allergy_intolerance_hash(resource)
    model_res = AllergyIntolerance.find(resource.id)
    model_res ||= AllergyIntolerance.new(resource, @fhir_bundle)
    {
      resource_type: resource.resourceType,
      resource: model_res
    }
  end

  def build_condition_hash(resource)
    model_res = Condition.find(resource.id)
    model_res ||= Condition.new(resource, @fhir_bundle)
    {
      resource_type: resource.resourceType,
      resource: model_res
    }
  end

  def build_composition_hash(resource)
    model_res = Composition.find(resource.id)
    model_res ||= Composition.new(resource, @fhir_bundle)
    {
      resource_type: 'Composition',
      resource: model_res
    }
  end

  def build_encounter_hash(resource)
    model_res = Encounter.find(resource.id)
    model_res ||= Encounter.new(resource, @fhir_bundle)
    {
      resource_type: 'Encounter',
      resource: model_res
    }
  end

  def build_immunization_hash(resource)
    model_res = Immunization.find(resource.id)
    model_res ||= Immunization.new(resource, @fhir_bundle)
    {
      resource_type: 'Immunization',
      resource: model_res
    }
  end

  def build_diagnostic_report_hash(resource)
    model_res = DiagnosticReport.find(resource.id)
    model_res ||= DiagnosticReport.new(resource, @fhir_bundle)
    {
      resource_type: 'DiagnosticReport',
      resource: model_res
    }
  end

  def build_document_reference_hash(resource)
    model_res = DocumentReference.find(resource.id)
    model_res ||= DocumentReference.new(resource, @fhir_bundle)
    {
      resource_type: 'DocumentReference',
      resource: model_res
    }
  end

  def build_device_hash(resource)
    model_res = Device.find(resource.id)
    model_res ||= Device.new(resource, @fhir_bundle)
    {
      resource_type: 'Device',
      resource: model_res
    }
  end

  def build_procedure_hash(resource)
    model_res = Procedure.find(resource.id)
    model_res ||= Procedure.new(resource, @fhir_bundle)
    {
      resource_type: 'Procedure',
      resource: model_res
    }
  end

  def build_immunization_report_hash(resource)
    model_res = ImmunizationRecommendation.find(resource.id)
    model_res ||= ImmunizationRecommendation.new(resource, @fhir_bundle)
    {
      resource_type: 'ImmunizationRecommendation',
      resource: model_res
    }
  end

  #-----------------------------------------------------------------------------
end
# rubocop:enable Metrics/ClassLength
