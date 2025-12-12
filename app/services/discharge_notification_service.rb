# Service to generate and push a FHIR discharge notification

class DischargeNotificationService

  def self.perform(fhir_server:, patient:, organization:, destination_endpoint:)
    # Get FHIR server information from DB if needed and set up client
    fhir_server = fhir_server.is_a?(String) ? FhirServer.find_by(base_url: fhir_server) : fhir_server
    fhir_client = FhirClientService.new(fhir_server: fhir_server).client
    # Create the message
    source_endpoint = fhir_server.base_url
    message = create_discharge_message(patient:, organization:, source_endpoint:, destination_endpoint:)
    # Write it to the FHIR server
    fhir_client.create(message)
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise 'Unable to write discharge notification to server due to request timeout'
  end

  # Generates a Da Vinci FHIR Discharge Notification Bundle
  #
  # @param patient [Patient] A valid Patient object containing a FHIR::Patient resource
  # @param organization [Organization] A valid Organization object containing a FHIR::Organization resource
  # @param source_endpoint [String] URL of the sending system
  # @param destination_endpoint [String] URL of the receiving system
  # @return [FHIR::Bundle]
  def self.create_discharge_message(patient:, organization:, source_endpoint:, destination_endpoint:)

    # 1. Generate ephemeral UUIDs for internal linking within the Bundle
    # These are used for the 'fullUrl' and 'reference' fields.
    msg_header_uuid = "urn:uuid:#{SecureRandom.uuid}"
    encounter_uuid  = "urn:uuid:#{SecureRandom.uuid}"
    patient_uuid    = "urn:uuid:#{SecureRandom.uuid}"
    org_uuid        = "urn:uuid:#{SecureRandom.uuid}"

    # 2. Create the Encounter Resource
    # Hardcoded per requirements: System ID, Emergency Class, Discharge Now
    # TODO: We're missing some required fields, see https://build.fhir.org/ig/HL7/davinci-alerts/StructureDefinition-adt-notification-encounter.html
    encounter = FHIR::Encounter.new(
      id: "encounter-#{SecureRandom.hex(4)}",
      meta: FHIR::Meta.new(
        profile: [
          "http://hl7.org/fhir/us/davinci-alerts/StructureDefinition/adt-notification-encounter",
          "http://hl7.org/fhir/us/core/StructureDefinition/us-core-encounter"
        ]
      ),
      status: 'finished',
      class: FHIR::Coding.new(
        system: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
        code: "EMER",
        display: "emergency"
      ),
      # Link to the Patient UUID defined above
      subject: FHIR::Reference.new(
        reference: patient_uuid,
        display: patient.name
      ),
      # Link to the Organization UUID defined above
      serviceProvider: FHIR::Reference.new(
        reference: org_uuid,
        display: organization.name
      ),
      period: FHIR::Period.new(
        end: DateTime.now.iso8601 # Discharge time is NOW
      )
      # NOTE: hospitalization is optional, but maybe of interest?
    )

    # 3. Create the MessageHeader Resource
    # This orchestrates the notification event
    message_header = FHIR::MessageHeader.new(
      id: SecureRandom.uuid,
      meta: FHIR::Meta.new(
        profile: ["http://hl7.org/fhir/us/davinci-alerts/StructureDefinition/discharge-notification-messageheader"]
      ),
      eventCoding: FHIR::Coding.new(
        system: "http://hl7.org/fhir/us/davinci-alerts/CodeSystem/notification-event",
        code: "notification-discharge",
        display: "Discharge Notification"
      ),
      source: FHIR::MessageHeader::Source.new(
        name: organization.name,
        endpoint: source_endpoint
      ),
      destination: [
        FHIR::MessageHeader::Destination.new(
          endpoint: destination_endpoint
        )
      ],
      sender: FHIR::Reference.new(
        reference: org_uuid
      ),
      focus: [
        FHIR::Reference.new(
          reference: encounter_uuid
        )
      ]
    )

    # 4. Construct (and return) the Bundle
    FHIR::Bundle.new(
      id: SecureRandom.uuid,
      meta: FHIR::Meta.new(
        profile: ["http://hl7.org/fhir/us/davinci-alerts/StructureDefinition/notifications-bundle"]
      ),
      type: 'message',
      timestamp: DateTime.now.iso8601,
      entry: [
        # Header must be the first entry
        FHIR::Bundle::Entry.new(fullUrl: msg_header_uuid, resource: message_header),
        FHIR::Bundle::Entry.new(fullUrl: encounter_uuid,  resource: encounter),
        # TODO: Maybe we want to simplify the included patient resource?
        FHIR::Bundle::Entry.new(fullUrl: patient_uuid,    resource: patient.fhir_resource),
        FHIR::Bundle::Entry.new(fullUrl: org_uuid,        resource: organization.fhir_resource)
        # TODO: We want to add a second focus as a document reference
      ]
    )
  end

end
