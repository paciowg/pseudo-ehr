class Organization < Resource
  attr_reader :fhir_resource, :id, :name

  def initialize(fhir_organization)
    @fhir_resource = fhir_organization
    @id = fhir_organization.id
    @name = fhir_organization.name
    self.class.update(self)
  end

  # We want a plausible endpoint URL for any organization for discharge notifications
  def endpoint_url
    # Use the endpoint specified by the organization if available, otherwise make up something reasonable
    if @fhir_resource.endpoint.present?
      endpoint_reference = @fhir_resource.endpoint.first.reference
      endpoint = PatientRecordCache.lookup_by_reference(endpoint_reference)
      endpoint&.address
    else
      "https://#{name.downcase.gsub(/\s/, '')}.org/fhir"
    end
  end
end
