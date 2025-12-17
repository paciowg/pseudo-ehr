class Organization < Resource
  attr_reader :fhir_resource, :id, :name

  def initialize(fhir_organization)
    @fhir_resource = fhir_organization
    @id = fhir_organization.id
    @name = fhir_organization.name
    self.class.update(self)
  end

  # We want a plausible endpoint URL for any organization for discharge notifications
  # TODO: If we support endpoints in the sample data eventually, use that
  def endpoint_url
    "https://#{name.downcase.gsub(/\s/, '')}.org/fhir"
  end
end
