# ServiceRequest Model
class ServiceRequest < Resource
  attr_reader :id, :status, :intent, :category, :code, :priority, :occurence,
              :authored_on, :performer, :performer_reference, :requester,
              :fhir_resource, :date, :reason

  def initialize(fhir_service_request, bundle_entries = [])
    @id = fhir_service_request.id
    @fhir_resource = fhir_service_request
    @status = fhir_service_request.status&.capitalize
    @intent = fhir_service_request.intent&.capitalize
    @category = read_category(fhir_service_request.category)
    @reason = read_reason(fhir_service_request.reasonReference, bundle_entries)
    @code = coding_string(fhir_service_request.code&.coding)
    @priority = fhir_service_request.priority&.capitalize
    @occurence = parse_date(fhir_service_request.occurrenceDateTime || fhir_service_request.occurrencePeriod&.start)
    @date = fhir_service_request.authoredOn
    @authored_on = parse_date(fhir_service_request.authoredOn)
    @performer = parse_provider_name(fhir_service_request.performer.first, bundle_entries)
    @performer_reference = fhir_service_request.performer.first&.reference
    @requester = parse_provider_name(fhir_service_request.requester, bundle_entries)
  end

  private

  def read_category(category)
    category&.map { |c| read_codeable_concept(c) }&.join(', ')
  end

  def read_codeable_concept(codeable_concept)
    c = codeable_concept&.coding&.first
    c&.display ? c.display : c&.code&.gsub('-', ' ')&.titleize
  end

  def read_reason(reason_refs, bundle_entries)
    return '--' if reason_refs.blank?

    reasons = []
    reason_refs&.each do |reason_ref|
      resource_type, resource_id = reason_ref.reference.split('/')
      reason_resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }
      next unless reason_resource

      case resource_type
      when 'Condition'
        reasons << Condition.new(reason_resource, bundle_entries).code
      end
    end

    reasons.compact.uniq.join(', ').presence || '--'
  end
end
