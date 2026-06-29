class PatientMatchOrCreateService
  def self.perform(fhir_server:, patient:)
    new(fhir_server:, patient:).perform
  end

  def initialize(fhir_server:, patient:)
    @fhir_server = fhir_server
    @patient = patient
    @client = FhirClientService.new(fhir_server: fhir_server).client
  end

  def perform
    matched_patient = match_by_identifier || match_by_name
    return build_result(matched_patient, created: false) if matched_patient.present?

    created_patient = create_patient
    build_result(created_patient, created: true)
  end

  private

  def build_result(patient_resource, created:)
    patient_id = patient_resource.respond_to?(:id) ? patient_resource.id : patient_resource&.dig('id')

    {
      patient_id: patient_id,
      created: created,
      resource: patient_resource
    }
  end

  def match_by_identifier
    identifiers = Array(@patient.fhir_resource.identifier).select do |identifier|
      identifier.system.present? && identifier.value.present?
    end

    identifiers.each do |identifier|
      bundle = search_patient(identifier: "#{identifier.system}|#{identifier.value}")
      patient_resource = first_patient_from_bundle(bundle)
      return patient_resource if patient_resource.present?
    rescue StandardError => e
      Rails.logger.warn("Patient identifier search failed on #{@fhir_server.base_url}: #{e.message}")
    end

    nil
  end

  def match_by_name
    return nil if @patient.first_name.blank? || @patient.last_name.blank?

    bundle = search_patient(family: @patient.last_name, given: @patient.first_name)
    first_patient_from_bundle(bundle)
  rescue StandardError => e
    Rails.logger.warn("Patient name search failed on #{@fhir_server.base_url}: #{e.message}")
    nil
  end

  def search_patient(search_params)
    reply = @client.search(FHIR::Patient, search: { parameters: search_params })

    if reply.respond_to?(:resource)
      reply.resource
    elsif reply.respond_to?(:response) && reply.response.is_a?(Hash)
      body = reply.response[:body]
      body.present? ? FHIR.from_contents(body) : nil
    else
      nil
    end
  end

  def first_patient_from_bundle(bundle)
    return nil unless bundle.respond_to?(:entry)

    entry = Array(bundle.entry).find { |bundle_entry| bundle_entry.resource&.resourceType == 'Patient' }
    entry&.resource
  end

  def create_patient
    patient_resource = FHIR.from_contents(@patient.fhir_resource.to_json)
    patient_resource.id = nil if patient_resource.respond_to?(:id=)
    patient_resource.meta = nil if patient_resource.respond_to?(:meta=)

    response = @client.create(patient_resource)
    created_resource = response.respond_to?(:resource) ? response.resource : nil

    return created_resource if created_resource.present?

    location = response.respond_to?(:response) ? response.response&.dig(:headers, :location) : nil
    patient_id = location.to_s.split('/').last
    raise 'Failed to create patient on destination server' if patient_id.blank?

    patient_resource.id = patient_id
    patient_resource
  end
end
