# ServiceRequest Model
class ServiceRequest < Resource
  attr_reader :id, :status, :intent, :category, :code, :priority, :occurence,
              :authored_on, :performer_name, :performer_reference, :requester,
              :fhir_resource

  def initialize(fhir_service_request, bundle_entries = [])
    @id = fhir_service_request.id
    @fhir_resource = fhir_service_request
    @status = fhir_service_request.status
    @intent = fhir_service_request.intent
    @category = read_category(fhir_service_request.category)
    @code = coding_string(fhir_service_request.code&.coding)
    @priority = fhir_service_request.priority
    @occurence = parse_date(fhir_service_request.occurrenceDateTime)
    @authored_on = parse_date(fhir_service_request.authoredOn)
    @performer_name = fhir_service_request.performer&.first&.display
    @performer_reference = fhir_service_request.performer.first&.reference
    @requester = read_requester_name(fhir_service_request.requester, bundle_entries)
  end

  private

  def read_category(category)
    category&.map { |c| read_codeable_concept(c) }&.join(', ')
  end

  def read_codeable_concept(codeable_concept)
    c = codeable_concept&.coding&.first
    c&.display ? c.display : c&.code&.gsub('-', ' ')&.titleize
  end

  def read_requester_name(requester_ref, bundle_entries)
    resource_type, resource_id = requester_ref.reference.split('/')
    requester_resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }
    return '--' unless requester_resource

    case resource_type
    when 'Practitioner', 'Patient', 'RelatedPerson'
      format_name(requester_resource.name) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    when 'Organization'
      requester_resource.name
    when 'PractitionerRole'
      name = requester_resource.practitioner.display
      return name if name

      practioner_id = requester_resource.practitioner.reference.split('/').last
      practitioner = bundle_entries.find { |res| res.resourceType == 'Practitioner' && res.id == practioner_id }
      format_name(practitioner.name) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    end
  end
end
