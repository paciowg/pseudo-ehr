class TransitionOfCareDocumentReferenceService
  PROFILE_URL = 'http://hl7.org/fhir/us/pacio-toc/StructureDefinition/TOC-DocumentReference'.freeze
  TYPE_SYSTEM = 'http://loinc.org'.freeze
  TYPE_CODE = '18761-7'.freeze
  TYPE_DISPLAY = 'Transfer Summary Note'.freeze
  CATEGORY_SYSTEM = 'http://hl7.org/fhir/us/core/CodeSystem/us-core-documentreference-category'.freeze
  CATEGORY_VERSION = '8.0.1'.freeze
  CATEGORY_CODE = 'clinical-note'.freeze

  def self.perform(fhir_server:, patient_id:, patient_name:, document_url:, document_description: nil)
    new(
      fhir_server:,
      patient_id:,
      patient_name:,
      document_url:,
      document_description:
    ).perform
  end

  def initialize(fhir_server:, patient_id:, patient_name:, document_url:, document_description: nil)
    @fhir_server = fhir_server
    @patient_id = patient_id
    @patient_name = patient_name
    @document_url = document_url
    @document_description = document_description
    @client = FhirClientService.new(fhir_server: fhir_server).client
  end

  def perform
    document_reference = build_document_reference
    @client.create(document_reference)
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise 'Unable to write Transition of Care DocumentReference to server due to request timeout'
  end

  private

  def build_document_reference
    now = Time.current.iso8601

    FHIR::DocumentReference.new(
      meta: FHIR::Meta.new(
        profile: [PROFILE_URL]
      ),
      text: FHIR::Narrative.new(
        status: 'generated',
        div: %(<div xmlns="http://www.w3.org/1999/xhtml"><p>Transition of Care DocumentReference for Patient #{ERB::Util.html_escape(@patient_name)}</p></div>)
      ),
      status: 'current',
      docStatus: 'final',
      description: @document_description,
      type: FHIR::CodeableConcept.new(
        coding: [
          FHIR::Coding.new(
            system: TYPE_SYSTEM,
            code: TYPE_CODE,
            display: TYPE_DISPLAY
          )
        ]
      ),
      category: [
        FHIR::CodeableConcept.new(
          coding: [
            FHIR::Coding.new(
              system: CATEGORY_SYSTEM,
              version: CATEGORY_VERSION,
              code: CATEGORY_CODE
            )
          ]
        )
      ],
      subject: FHIR::Reference.new(
        reference: "Patient/#{@patient_id}"
      ),
      date: now,
      content: [
        FHIR::DocumentReference::Content.new(
          attachment: FHIR::Attachment.new(
            contentType: 'application/fhir+json',
            url: @document_url,
            creation: now
          )
        )
      ]
    )
    # Optional point-of-contact extension could be added here in the future.
  end
end
