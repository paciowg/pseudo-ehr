class Organization < Resource
  attr_reader :fhir_resource, :id, :name

  def initialize(fhir_organization)
    @fhir_resource = fhir_organization
    @id = fhir_organization.id
    @name = fhir_organization.name
    self.class.update(self)
  end
end
