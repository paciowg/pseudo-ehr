class TransitionOfCareCompositionService
  PROFILE_URL = 'http://hl7.org/fhir/us/pacio-toc/StructureDefinition/TOC-Composition'.freeze
  LIST_EMPTY_REASON_SYSTEM = 'http://terminology.hl7.org/CodeSystem/list-empty-reason'.freeze
  DEFAULT_LANGUAGE = 'en-US'.freeze
  IDENTIFIER_SYSTEM = 'urn:ietf:rfc:3986'.freeze

  SECTION_DEFINITIONS = [
    {
      key: :advance_directives,
      title: 'Advance Directives',
      code_system: 'http://loinc.org',
      code: '42348-3',
      display: 'Advance healthcare directives',
      supported_in_ui: true,
      default_empty_reason: 'nilknown',
      legacy_codes: []
    },
    {
      key: :allergies,
      title: 'Allergies and Intolerances',
      code_system: 'http://loinc.org',
      code: '48765-2',
      display: 'Allergies and adverse reactions Document',
      supported_in_ui: true,
      default_empty_reason: 'notasked',
      legacy_codes: []
    },
    {
      key: :behavioral_health,
      title: 'Behavioral Health',
      code_system: 'http://hl7.org/fhir/us/pacio-toc/CodeSystem/toc-temp-cs',
      code: 'behavioral_health_summary',
      display: 'Behavioral Health Summary',
      supported_in_ui: false,
      default_empty_reason: 'notasked',
      legacy_codes: []
    },
    {
      key: :functional_status,
      title: 'Functional Status',
      code_system: 'http://loinc.org',
      code: '47420-5',
      display: 'Functional status',
      supported_in_ui: true,
      default_empty_reason: 'notasked',
      legacy_codes: []
    },
    {
      key: :immunizations,
      title: 'Immunizations',
      code_system: 'http://loinc.org',
      code: '11369-6',
      display: 'History of Immunization note',
      supported_in_ui: true,
      default_empty_reason: 'notasked',
      legacy_codes: ['82593-5']
    },
    {
      key: :discharge_instructions,
      title: 'Discharge Instructions',
      code_system: 'http://loinc.org',
      code: '69730-0',
      display: 'Discharge Instructions',
      supported_in_ui: false,
      default_empty_reason: 'notasked',
      legacy_codes: []
    },
    {
      key: :medical_devices,
      title: 'Medical Devices',
      code_system: 'http://loinc.org',
      code: '46264-8',
      display: 'History of medical device use',
      supported_in_ui: true,
      default_empty_reason: 'notasked',
      legacy_codes: []
    },
    {
      key: :medications,
      title: 'Medications',
      code_system: 'http://loinc.org',
      code: '10160-0',
      display: 'History of Medication Use',
      supported_in_ui: true,
      default_empty_reason: 'notasked',
      legacy_codes: ['10183-2']
    },
    {
      key: :plan_of_care,
      title: 'Plan of Care',
      code_system: 'http://loinc.org',
      code: '18776-5',
      display: 'Plan of care note',
      supported_in_ui: false,
      default_empty_reason: 'notasked',
      legacy_codes: []
    },
    {
      key: :problems,
      title: 'Problems',
      code_system: 'http://loinc.org',
      code: '11450-4',
      display: 'Problem list - Reported',
      supported_in_ui: true,
      default_empty_reason: 'notasked',
      legacy_codes: ['46019-6']
    },
    {
      key: :procedures,
      title: 'Procedures',
      code_system: 'http://loinc.org',
      code: '47519-4',
      display: 'History of Procedures Document',
      supported_in_ui: true,
      default_empty_reason: 'notasked',
      legacy_codes: ['28570-0']
    },
    {
      key: :reason_for_referral,
      title: 'Reason for Transfer',
      code_system: 'http://loinc.org',
      code: '42349-1',
      display: 'Reason for referral (narrative)',
      supported_in_ui: false,
      default_empty_reason: 'notasked',
      legacy_codes: []
    },
    {
      key: :clinical_results,
      title: 'Clinical Results',
      code_system: 'http://loinc.org',
      code: '30954-2',
      display: 'Relevant diagnostic tests/laboratory data note',
      supported_in_ui: true,
      default_empty_reason: 'notasked',
      legacy_codes: ['19146-0']
    },
    {
      key: :social_history,
      title: 'Social History',
      code_system: 'http://loinc.org',
      code: '29762-2',
      display: 'Social history note',
      supported_in_ui: false,
      default_empty_reason: 'notasked',
      legacy_codes: []
    },
    {
      key: :vital_signs,
      title: 'Vital Signs',
      code_system: 'http://loinc.org',
      code: '8716-3',
      display: 'Vital signs note',
      supported_in_ui: true,
      default_empty_reason: 'notasked',
      legacy_codes: ['LP30605-7']
    }
  ].freeze

  class << self
    def build(patient_id:, toc_params:)
      new(patient_id: patient_id, toc_params: toc_params).build
    end

    def rebuild(composition:, patient_id:, toc_params:)
      new(patient_id: patient_id, toc_params: toc_params, composition: composition).rebuild
    end

    def section_definitions
      SECTION_DEFINITIONS
    end
  end

  def initialize(patient_id:, toc_params:, composition: nil)
    @patient_id = patient_id
    @toc_params = toc_params || {}
    @composition = composition
  end

  def build
    composition = FHIR::Composition.new(
      meta: {
        profile: [PROFILE_URL]
      },
      language: DEFAULT_LANGUAGE,
      identifier: build_identifier,
      status: 'final',
      type: build_type,
      category: build_category,
      subject: {
        reference: "Patient/#{@patient_id}"
      },
      date: Time.now.iso8601,
      title: @toc_params[:title],
      author: [
        {
          reference: @toc_params[:author]
        }
      ],
      custodian: {
        reference: @toc_params[:custodian]
      }
    )

    composition.section = build_sections
    composition
  end

  def rebuild
    @composition.meta ||= FHIR::Meta.new
    @composition.meta.profile = normalized_profiles(@composition.meta.profile)

    @composition.language = @composition.language.presence || DEFAULT_LANGUAGE
    @composition.identifier ||= build_identifier
    @composition.title = @toc_params[:title]
    @composition.date = Time.now.iso8601
    @composition.section = build_sections

    @composition
  end

  private

  def build_sections
    selected_sections = selected_section_params_by_key

    SECTION_DEFINITIONS.map do |definition|
      selected_section = selected_sections[definition[:key]]
      section_title = selected_section&.dig(:title).presence || definition[:title]
      entries = Array(selected_section&.dig(:entries)).reject(&:blank?).uniq

      build_section(definition: definition, title: section_title, entries: entries)
    end
  end

  def build_section(definition:, title:, entries:)
    section = FHIR::Composition::Section.new(
      title: title,
      code: FHIR::CodeableConcept.new(
        coding: [
          FHIR::Coding.new(
            system: definition[:code_system],
            code: definition[:code],
            display: definition[:display]
          )
        ]
      ),
      text: FHIR::Narrative.new(
        status: 'additional',
        div: narrative_div(title)
      )
    )

    if entries.present?
      section.entry = entries.map { |entry| FHIR::Reference.new(reference: entry) }
    else
      section.emptyReason = FHIR::CodeableConcept.new(
        coding: [
          FHIR::Coding.new(
            system: LIST_EMPTY_REASON_SYSTEM,
            code: definition[:default_empty_reason]
          )
        ]
      )
    end

    section
  end

  def selected_section_params_by_key
    Array(@toc_params[:sections]).each_with_object({}) do |section_params, memo|
      next unless section_params[:include] == '1'

      definition = definition_for_params(section_params)
      next unless definition

      memo[definition[:key]] = {
        title: section_params[:title],
        entries: section_params[:entries]
      }
    end
  end

  def definition_for_params(section_params)
    code = section_params[:code].to_s
    code_system = section_params[:code_system].to_s.presence

    SECTION_DEFINITIONS.find do |definition|
      next false unless definition[:code] == code || definition[:legacy_codes].include?(code)

      code_system.blank? || definition[:code_system] == code_system || definition[:legacy_codes].include?(code)
    end
  end

  def build_identifier
    FHIR::Identifier.new(
      system: IDENTIFIER_SYSTEM,
      value: "urn:uuid:#{SecureRandom.uuid}"
    )
  end

  def build_type
    FHIR::CodeableConcept.new(
      coding: [
        FHIR::Coding.new(
          system: 'http://loinc.org',
          code: '11490-0',
          display: 'Physician Discharge summary'
        )
      ]
    )
  end

  def build_category
    [
      FHIR::CodeableConcept.new(
        coding: [
          FHIR::Coding.new(
            system: 'http://loinc.org',
            code: '18761-7',
            display: 'Transfer Summary Note'
          )
        ]
      )
    ]
  end

  def normalized_profiles(existing_profiles)
    profiles = Array(existing_profiles).compact
    profiles << PROFILE_URL unless profiles.include?(PROFILE_URL)
    profiles
  end

  def narrative_div(title)
    %(<div xmlns="http://www.w3.org/1999/xhtml">#{ERB::Util.html_escape(title)}</div>)
  end
end
