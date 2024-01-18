# frozen_string_literal: true

# CareTeamParticipant Model
class CareTeamParticipant < Resource
  attr_reader :name, :role, :organization, :contact, :fhir_resource

  def initialize(name, role, fhir_resource)
    @fhir_resource = fhir_resource
    @name = name || retrieve_provider_name
    @role = role || retrieve_provider_role
    @organization = retrieve_organization_name
    @contact = retrieve_contact
  end

  private

  # Retrieve provider name from either the PractitionerRole, RelatedPerson, Patient or Practitioner resource.
  def retrieve_provider_name
    name = @fhir_resource.try(:practitioner)&.display
    if name.blank?
      fhir_name_array = @fhir_resource.try(:name) || []
      format_name(fhir_name_array) => { first_name:, last_name: }
      name = "#{first_name} #{last_name}"
    end
    name || '--'
  end

  # Retrieve the provider role from PractitionerRole resource
  def retrieve_provider_role
    coding = @fhir_resource.try(:specialty)&.first&.coding&.first
    coding&.display || conding&.code || '--'
  end

  # Retrieve provider org from PractionerRole or Practioner resource
  def retrieve_organization_name
    @fhir_resource.try(:organization).try(:display) || '--'
  end

  # Retrieve provider contact info from either PractitionerRole, RelatedPerson, Patient or Practitioner resource.
  def retrieve_contact
    telecom_array = @fhir_resource.try(:telecom) || @fhir_resource.try(:contact)&.first&.telecom || []
    phone = format_phone(telecom_array)
    phone != '--' ? phone : format_email(telecom_array)
  end
end
