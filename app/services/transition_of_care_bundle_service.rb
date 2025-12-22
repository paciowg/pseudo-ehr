class TransitionOfCareBundleService
  def self.perform(fhir_server:, composition_id:)
    new(fhir_server, composition_id).perform
  end

  def initialize(fhir_server, composition_id)
    @fhir_server = fhir_server.is_a?(String) ? FhirServer.find_by(base_url: fhir_server) : fhir_server
    @composition_id = composition_id
    @resources_map = {}
    @uuid_map = {}
  end

  def perform
    # Fetch Composition from cache
    comp_wrapper = PatientRecordCache.lookup('Composition', @composition_id)
    raise "Composition with ID #{@composition_id} not found in cache" unless comp_wrapper

    composition = unwrap_resource(comp_wrapper)

    # Initialize maps with the composition itself
    comp_key = generate_key(composition)
    comp_uuid = "urn:uuid:#{SecureRandom.uuid}"
    @resources_map[comp_key] = composition
    @uuid_map[comp_key] = comp_uuid

    # Identify Patient reference (expected to be the second entry)
    patient_ref = composition.subject&.reference

    # Collect all resources referenced by the composition
    refs = extract_references(composition)
    refs.each do |ref|
      collect_resource(ref)
    end

    # Handle Medication Lists: Aggregate multiple Lists into a single SMP Bundle
    # and update the Composition to reference that Bundle instead.
    handle_medication_lists(composition)

    # Build Entries
    entries = []

    # 1. Composition Entry (Must be first)
    entries << build_entry(composition)

    # 2. Patient Entry (Must be second)
    patient_resource = find_patient_resource(patient_ref)
    if patient_resource
      entries << build_entry(patient_resource)
    end

    # 3. Other Entries
    @resources_map.values.uniq.each do |resource|
      # Skip if it's the composition or the patient we already added
      next if resource.id == composition.id && resource.resourceType == 'Composition'
      next if patient_resource && resource.id == patient_resource.id && resource.resourceType == 'Patient'

      # Skip List resources as they are now consolidated into the SMP Bundle created in handle_medication_lists
      next if resource.resourceType == 'List'

      entries << build_entry(resource)
    end

    # Create the Document Bundle
    bundle = FHIR::Bundle.new(
      id: SecureRandom.uuid,
      type: 'document',
      timestamp: Time.now.iso8601,
      identifier: FHIR::Identifier.new(
        system: 'urn:ietf:rfc:3986',
        value: "urn:uuid:#{SecureRandom.uuid}"
      ),
      entry: entries
    )

    # Submit to FHIR Server
    client = FhirClientService.new(fhir_server: @fhir_server).client
    response = client.create(bundle)

    raise "Failed to submit TOC Bundle: #{response.response[:body]}" unless response.response[:code].to_s.start_with?('2')

    # Return the full URL of the created bundle
    id = response.resource.id
    base = @fhir_server.base_url.chomp('/')
    "#{base}/Bundle/#{id}"
  end

  private

  def unwrap_resource(wrapper)
    wrapper.respond_to?(:fhir_resource) ? wrapper.fhir_resource : wrapper
  end

  def handle_medication_lists(composition)
    # Identify all collected List resources (Medication Lists)
    list_resources = @resources_map.values.select { |r| r.resourceType == 'List' }
    return if list_resources.empty?

    # Create the Standardized Medication Profile (SMP) Bundle from all lists
    list_ids = list_resources.map(&:id)
    smp_bundle = StandardizedMedicationProfileBundleService.perform(medication_list_ids: list_ids)

    # Register the new Bundle in the maps so it gets built as an entry
    smp_key = generate_key(smp_bundle)
    smp_uuid = "urn:uuid:#{SecureRandom.uuid}"

    @resources_map[smp_key] = smp_bundle
    @uuid_map[smp_key] = smp_uuid

    # Update Composition Sections:
    # Replace references to the individual Lists with a single reference to the SMP Bundle.
    list_refs = list_resources.map { |r| "#{r.resourceType}/#{r.id}" }

    composition.section.each do |section|
      # Identify entries in this section that point to any of our Lists
      entries_to_replace = section.entry.select { |e| list_refs.include?(e.reference) }

      if entries_to_replace.any?
        # Remove the old List references
        section.entry.reject! { |e| list_refs.include?(e.reference) }

        # Add the single reference to the new SMP Bundle
        # We use the UUID directly because the Composition will be serialized shortly after
        section.entry << FHIR::Reference.new(reference: smp_uuid)
      end
    end

    # Remove the original List resources from the map so they don't get added as individual entries
    list_resources.each { |r| @resources_map.delete(generate_key(r)) }
  end

  def generate_key(resource)
    "#{resource.resourceType}/#{resource.id}"
  end

  def find_patient_resource(patient_ref)
    # Try finding by direct reference string mapping
    if patient_ref && @resources_map[patient_ref]
      return @resources_map[patient_ref]
    end

    # Try finding by the key generated from the resource if we have a uuid mapping
    if patient_ref && @uuid_map[patient_ref]
      uuid = @uuid_map[patient_ref]
      return @resources_map.values.find { |r| @uuid_map[generate_key(r)] == uuid }
    end

    # Fallback: Find any Patient resource in the map
    @resources_map.values.find { |r| r.resourceType == 'Patient' }
  end

  def collect_resource(ref_string)
    # Avoid re-processing
    return if @uuid_map[ref_string]

    # Extract type and ID from reference (e.g. "Patient/123" -> "Patient" and "123")
    type, id = ref_string.split('/', 2)

    # Retrieve from cache
    wrapper = PatientRecordCache.lookup(type, id)
    return unless wrapper

    resource = unwrap_resource(wrapper)
    key = generate_key(resource)

    # Generate a UUID if we haven't seen this resource object before
    uuid = @uuid_map[key] || "urn:uuid:#{SecureRandom.uuid}"

    @resources_map[key] = resource
    @uuid_map[key] = uuid

    # Also map the requested ref_string to this UUID
    @uuid_map[ref_string] = uuid if ref_string != key
  end

  def extract_references(resource)
    refs = []
    scan_for_refs(resource.to_hash, refs)
    refs
  end

  def scan_for_refs(hash, refs)
    return unless hash.is_a?(Hash)

    if hash['reference'].is_a?(String)
      refs << hash['reference']
    end

    hash.each_value do |value|
      if value.is_a?(Hash)
        scan_for_refs(value, refs)
      elsif value.is_a?(Array)
        value.each { |item| scan_for_refs(item, refs) if item.is_a?(Hash) }
      end
    end
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
