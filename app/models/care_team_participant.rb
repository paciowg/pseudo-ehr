# frozen_string_literal: true

# CareTeamParticipant Model
class CareTeamParticipant < Resource
  attr_reader :name, :role, :organization, :contact, :fhir_resource

  def initialize(name, role, fhir_resource, bundle_entries = [])
    @fhir_resource = fhir_resource
    @name = name || retrieve_provider_name
    @role = role || retrieve_provider_role
    @organization = retrieve_organization_name(bundle_entries)
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
  def retrieve_organization_name(bundle_entries)
    org = @fhir_resource.try(:organization)
    return '--' unless org

    name = org.try(:display)
    return name if name

    org_ref = org.try(:reference)
    return '--' unless org_ref

    resource_type, resource_id = org_ref.split('/')
    resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

    resource&.name || '--'
  end

  # Retrieve provider contact info from either PractitionerRole, RelatedPerson, Patient or Practitioner resource.
  def retrieve_contact
    telecom_array = @fhir_resource.try(:telecom) || @fhir_resource.try(:contact)&.first&.telecom || []
    phone = format_phone(telecom_array)
    phone != '--' ? phone : format_email(telecom_array)
  end
end
