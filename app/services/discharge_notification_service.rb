# Service to generate and push a FHIR discharge notification

class DischargeNotificationService
  def self.perform(fhir_server:, patient:, source_organization:, destination_organization:, document_url: nil, document_description: nil)
    # Get FHIR server information from DB if needed and set up client
    fhir_server = FhirServer.find_by(base_url: fhir_server) if fhir_server.is_a?(String)
    fhir_client = FhirClientService.new(fhir_server: fhir_server).client
    # Create the message
    message = create_discharge_message(patient:, source_organization:, destination_organization:, document_url:, document_description:)
    # Write it to the FHIR server
    fhir_client.create(message)
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise 'Unable to write discharge notification to server due to request timeout'
  end

  # Generates a Da Vinci FHIR Discharge Notification Bundle
  #
  # @param patient [Patient] A valid Patient object containing a FHIR::Patient resource
  # @param source_organization [Organization] A valid Organization object containing a FHIR::Organization resource
  # @param destination_organization [Organization] A valid Organization object containing a FHIR::Organization resource
  # @param document_url [String] Optional URL of a document to include
  # @param document_description [String] Optional description of the document
  # @return [FHIR::Bundle]
  def self.create_discharge_message(patient:, source_organization:, destination_organization:, document_url: nil, document_description: nil)
    # 1. Generate ephemeral UUIDs for internal linking within the Bundle
    # These are used for the 'fullUrl' and 'reference' fields.
    msg_header_uuid = "urn:uuid:#{SecureRandom.uuid}"
    encounter_uuid  = "urn:uuid:#{SecureRandom.uuid}"
    patient_uuid    = "urn:uuid:#{SecureRandom.uuid}"
    org_uuid        = "urn:uuid:#{SecureRandom.uuid}"
    doc_ref_uuid    = "urn:uuid:#{SecureRandom.uuid}" if document_url.present?

    # 2. Create the Encounter Resource
    # Hardcoded for demonstration: class and type
    encounter = FHIR::Encounter.new(
      id: "encounter-#{SecureRandom.hex(4)}",
      meta: FHIR::Meta.new(
        profile: [
          'http://hl7.org/fhir/us/davinci-alerts/StructureDefinition/adt-notification-encounter',
          'http://hl7.org/fhir/us/core/StructureDefinition/us-core-encounter'
        ]
      ),
      status: 'finished',
      class: FHIR::Coding.new(
        system: 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
        code: 'EMER',
        display: 'emergency'
      ),
      type: [
        FHIR::CodeableConcept.new(
          coding: [
            FHIR::Coding.new(
              system: 'http://snomed.info/sct',
              code: '4525004',
              display: 'Emergency department patient visit'
            )
          ]
        )
      ],
      # Link to the Patient UUID defined above
      subject: FHIR::Reference.new(
        reference: patient_uuid,
        display: patient.name
      ),
      # Link to the Organization UUID defined above
      # NOTE: serviceProvider and location are optional, we could remove serviceProvider (simplify) or add
      # location (since it's optional but must support)
      serviceProvider: FHIR::Reference.new(
        reference: org_uuid,
        display: source_organization.name
      ),
      period: FHIR::Period.new(
        end: DateTime.now.iso8601 # Discharge time is NOW
      )
      # NOTE: hospitalization/dischargeDisposition is optional, but maybe of interest?
      # system: "http://www.nubc.org/patient-discharge"
      # code: "03"
      # display: "Discharged/transferred to a Skilled Nursing Facility (SNF) with Medicare Certification in anticipation of Skilled Care"
    )

    # 3. Create DocumentReference if needed
    if document_url.present?
      document_reference = FHIR::DocumentReference.new(
        status: 'current',
        description: document_description,
        subject: FHIR::Reference.new(reference: patient_uuid),
        content: [
          FHIR::DocumentReference::Content.new(
            attachment: FHIR::Attachment.new(
              url: document_url,
              contentType: 'application/fhir+json'
            )
          )
        ]
      )
    end

    # 4. Create the MessageHeader Resource
    # This orchestrates the notification event
    focus_references = [FHIR::Reference.new(reference: encounter_uuid)]
    focus_references << FHIR::Reference.new(reference: doc_ref_uuid) if document_url.present?

    message_header = FHIR::MessageHeader.new(
      id: SecureRandom.uuid,
      meta: FHIR::Meta.new(
        profile: ['http://hl7.org/fhir/us/davinci-alerts/StructureDefinition/discharge-notification-messageheader']
      ),
      eventCoding: FHIR::Coding.new(
        system: 'http://hl7.org/fhir/us/davinci-alerts/CodeSystem/notification-event',
        code: 'notification-discharge',
        display: 'Discharge Notification'
      ),
      source: FHIR::MessageHeader::Source.new(
        name: source_organization.name,
        endpoint: source_organization.endpoint_url
      ),
      destination: [
        FHIR::MessageHeader::Destination.new(
          name: destination_organization.name,
          endpoint: destination_organization.endpoint_url
        )
      ],
      sender: FHIR::Reference.new(
        reference: org_uuid
      ),
      focus: focus_references
    )

    # 5. Construct (and return) the Bundle
    entries = [
      # Header must be the first entry
      FHIR::Bundle::Entry.new(fullUrl: msg_header_uuid, resource: message_header),
      FHIR::Bundle::Entry.new(fullUrl: encounter_uuid,  resource: encounter),
      # TODO: Maybe we want to simplify the included patient resource?
      FHIR::Bundle::Entry.new(fullUrl: patient_uuid,    resource: patient.fhir_resource),
      FHIR::Bundle::Entry.new(fullUrl: org_uuid,        resource: source_organization.fhir_resource)
    ]
    entries << FHIR::Bundle::Entry.new(fullUrl: doc_ref_uuid, resource: document_reference) if document_url.present?

    FHIR::Bundle.new(
      id: SecureRandom.uuid,
      meta: FHIR::Meta.new(
        profile: ['http://hl7.org/fhir/us/davinci-alerts/StructureDefinition/notifications-bundle']
      ),
      type: 'message',
      timestamp: DateTime.now.iso8601,
      entry: entries
    )
  end
end
