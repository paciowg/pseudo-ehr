class StandardizedMedicationProfileBundleService
  # Creates a "Standardized Medication Profile" Bundle (Collection) from a cached Medication List.
  #
  # Usage:
  #   StandardizedMedicationProfileBundleService.perform(
  #     medication_list_ids: ['list-123', 'list-456'],
  #     fhir_server: 'http://hapi.fhir.org/baseR4' # Optional
  #   )
  #
  # Arguments:
  #   medication_list_ids: (Array<String>) The IDs of the FHIR List resources stored in PatientRecordCache.
  #   fhir_server: (String|FhirServer|nil) Optional. The target FHIR server.
  #                If provided, the generated bundle will be written to this server.
  #                If nil (default), the bundle is only generated and returned to the caller.
  #
  # Returns:
  #   (FHIR::Bundle) The generated collection bundle.

  def self.perform(medication_list_ids:, fhir_server: nil)
    new(medication_list_ids, fhir_server).perform
  end

  def initialize(medication_list_ids, fhir_server)
    @medication_list_ids = Array(medication_list_ids)
    if fhir_server
      @fhir_server = fhir_server.is_a?(String) ? FhirServer.find_by(base_url: fhir_server) : fhir_server
    end
    @resources_map = {}
    @uuid_map = {}
  end

  def perform
    medication_lists = []

    # Fetch Medication Lists from cache
    @medication_list_ids.each do |medication_list_id|
      list_wrapper = PatientRecordCache.lookup('List', medication_list_id)
      raise "Medication List with ID #{medication_list_id} not found in cache" unless list_wrapper

      medication_list = unwrap_resource(list_wrapper)
      medication_lists << medication_list

      # 1. Map the List itself
      collect_resource_object(medication_list)

      # 2. Traverse List entries
      medication_list&.entry&.each do |entry|
        resolve_medication_statement(entry.item)
      end
    end

    # 3. Build Entries
    entries = []

    # Lists first
    medication_lists.each do |medication_list|
      entries << build_entry(medication_list)
    end

    # Others
    @resources_map.each_value do |resource|
      next if resource.resourceType == 'List' && medication_lists.any? { |l| l.id == resource.id }

      entries << build_entry(resource)
    end

    # 4. Create Bundle
    bundle = FHIR::Bundle.new(
      id: SecureRandom.uuid,
      type: 'collection',
      timestamp: Time.now.iso8601,
      identifier: FHIR::Identifier.new(
        system: 'urn:ietf:rfc:3986',
        value: "urn:uuid:#{SecureRandom.uuid}"
      ),
      entry: entries
    )

    # 5. Write to server if provided
    if @fhir_server
      client = FhirClientService.new(fhir_server: @fhir_server).client
      response = client.create(bundle)

      unless response.response[:code].to_s.start_with?('2')
        raise "Failed to submit SMP Bundle: #{response.response[:body]}"
      end
    end

    # 6. Return bundle
    bundle
  end

  private

  def collect_resource_object(resource, source_ref_string = nil)
    key = generate_key(resource)
    uuid = @uuid_map[key] || "urn:uuid:#{SecureRandom.uuid}"

    unless @resources_map[key]
      @resources_map[key] = resource
      @uuid_map[key] = uuid
    end

    # Also map the specific reference string used to find this resource
    # so we can replace it in the parent resource later
    @uuid_map[source_ref_string] = uuid if source_ref_string
  end

  def resolve_medication_statement(reference)
    return unless reference&.reference

    wrapper = PatientRecordCache.lookup_by_reference(reference.reference)
    return unless wrapper

    resource = unwrap_resource(wrapper)
    collect_resource_object(resource, reference.reference)

    # Recursively resolve basedOn (MedicationRequest)
    return unless resource.respond_to?(:basedOn) && resource.basedOn

    resource.basedOn.each do |based_on_ref|
      resolve_medication_request(based_on_ref)
    end
  end

  def resolve_medication_request(reference)
    return unless reference&.reference

    wrapper = PatientRecordCache.lookup_by_reference(reference.reference)
    return unless wrapper

    resource = unwrap_resource(wrapper)
    collect_resource_object(resource, reference.reference)
  end

  def unwrap_resource(wrapper)
    wrapper.respond_to?(:fhir_resource) ? wrapper.fhir_resource : wrapper
  end

  def generate_key(resource)
    "#{resource.resourceType}/#{resource.id}"
  end

  def build_entry(resource)
    key = generate_key(resource)
    uuid = @uuid_map[key]

    # Serialize, rewrite references to UUIDs, and parse back
    hash = JSON.parse(resource.to_json)
    replace_refs(hash)
    new_resource = FHIR.from_contents(hash.to_json)

    FHIR::Bundle::Entry.new(
      fullUrl: uuid,
      resource: new_resource
    )
  end

  def replace_refs(hash)
    if hash['reference'].is_a?(String)
      uuid = @uuid_map[hash['reference']]
      hash['reference'] = uuid if uuid
    end

    hash.each_value do |value|
      if value.is_a?(Hash)
        replace_refs(value)
      elsif value.is_a?(Array)
        value.each { |item| replace_refs(item) if item.is_a?(Hash) }
      end
    end
  end
end
