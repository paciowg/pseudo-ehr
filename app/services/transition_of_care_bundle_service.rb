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

    if response.response[:code].to_s.start_with?('2')
      # Return the full URL of the created bundle
      id = response.resource.id
      base = @fhir_server.base_url.chomp('/')
      "#{base}/Bundle/#{id}"
    else
      raise "Failed to submit TOC Bundle: #{response.response[:body]}"
    end
  end

  private

  def unwrap_resource(wrapper)
    wrapper.respond_to?(:fhir_resource) ? wrapper.fhir_resource : wrapper
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
    if wrapper
      resource = unwrap_resource(wrapper)
      key = generate_key(resource)

      # Generate a UUID if we haven't seen this resource object before
      uuid = @uuid_map[key] || "urn:uuid:#{SecureRandom.uuid}"
      
      @resources_map[key] = resource
      @uuid_map[key] = uuid
      
      # Also map the requested ref_string to this UUID
      @uuid_map[ref_string] = uuid if ref_string != key
    end
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
    
    hash.each do |_, value|
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

    hash.each do |_, value|
      if value.is_a?(Hash)
        replace_refs(value)
      elsif value.is_a?(Array)
        value.each { |item| replace_refs(item) if item.is_a?(Hash) }
      end
    end
  end
end
