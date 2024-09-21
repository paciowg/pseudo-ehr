# Observation Model
class Observation < Resource
  attr_reader :id, :status, :category, :domain, :code, :effective_date_time,
              :performer, :derived_from, :measurement, :measurement_interpretation, :location, :members, :fhir_resource

  def initialize(fhir_observation, bundle_entries)
    @fhir_resource = fhir_observation
    @id = fhir_observation.id
    @status = fhir_observation.status
    @effective_date_time = fhir_observation.effectiveDateTime
    @category = retrieve_category
    @domain = retrieve_domain
    @code = retrieve_code
    @performer = retrieve_performer_name(fhir_observation.performer, bundle_entries)
    @derived_from = retrieve_derived_from(fhir_observation.derivedFrom, fhir_observation.subject)
    value_quantity = fhir_observation.valueQuantity.presence || fhir_observation.valueCodeableConcept
    @measurement = retrieve_mesearement(value_quantity)
    @measurement_interpretation = fhir_observation.try(:interpretation)&.map(&:text)&.join(', ').presence || '--'
    @location = retrieve_location(bundle_entries)
    @members = retrieve_members(fhir_observation.hasMember, bundle_entries)
  end

  def collection?
    @members.present?
  end

  def effective
    parse_date(@effective_date_time)
  end

  def self.collections(observations)
    observations.select(&:collection?)
                .sort_by { |observation| observation&.effective_date_time || '' }
                .reverse
  end

  def self.format_domain(domain_code)
    display = pfe_domain_dict[domain_code] || category_dict[domain_code]
    display.present? ? "#{display} (#{domain_code})" : domain_code
  end

  def self.group_by_category_and_domain(observations)
    sorted_observations = observations.reject(&:collection?)
                                      .sort_by { |observation| observation&.effective_date_time || '' }
                                      .reverse

    grouped_observations = {}

    sorted_observations.each do |observation|
      category = observation.category
      domain = observation.domain

      grouped_observations[category] ||= {}
      grouped_observations[category][domain] ||= []
      grouped_observations[category][domain] << observation
    end

    grouped_observations
  end

  def self.category_dict
    OBSERVATION_CATEGORY_DISPLAY
  end

  def self.internal_category_dict
    OBSERVATION_INTERNAL_CATEGORY_DISPLAY
  end

  def self.pfe_domain_dict
    OBSERVATION_PFE_DOMAIN_DISPLAY
  end

  private

  def retrieve_category
    list = %w[clinical-test functional-status cognitive-status survey activity laboratory]
    formatted_category = categories.select { |cat| list.include?(cat[:code]) }.map { |cat| cat[:code] }.sort.join(', ')

    Observation.internal_category_dict[formatted_category] || 'Other'
  end

  def retrieve_domain
    list = %w[clinical-test functional-status cognitive-status survey activity laboratory]
    domain = @category == 'Other' ? categories.last : categories.find { |cat| !list.include?(cat[:code]) }

    if domain.blank?
      ''
    else
      domain[:display] ? "#{domain[:display]} (#{domain[:code]})" : domain[:code]
    end
  end

  def retrieve_code
    obs_code = @fhir_resource.code.coding.first
    code = obs_code.code
    display = obs_code.display

    display.present? ? "#{display} (#{code})" : code
  end

  def retrieve_performer_name(performer, bundle_entries)
    performer.map do |performer_ref|
      name = performer_ref.display
      return name if name.present?

      resource_type, id = performer_ref.reference.split('/')
      ref_resource = bundle_entries.find { |entry| entry.resourceType == resource_type && entry.id == id }

      name = ref_resource.try(:practitioner)&.display
      return name if name.present?

      fhir_name_array = ref_resource.try(:name) || []
      format_name(fhir_name_array) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    end.join(', ')
  end

  def retrieve_location(bundle_entries)
    location_ext = @fhir_resource.extension.find { |ext| ext.url == 'http://hl7.org/fhir/StructureDefinition/event-location' }
    return 'Not provided' if location_ext.blank?

    location_ref = location_ext.valueReference&.reference
    resource_type, id = location_ref&.split('/')
    ref_resource = bundle_entries.find { |entry| entry.resourceType == resource_type && entry.id == id }

    ref_resource&.name || 'Not provided'
  end

  def retrieve_derived_from(fhir_derived_from, patient_ref)
    patient_id = patient_ref.reference.split('/').last
    fhir_derived_from.map do |elmt|
      resource_type, id = elmt.reference.split('/')
      name = "#{resource_type}-#{id} "
      path = "/patients/#{patient_id}/#{resource_type.downcase}s/#{id}"
      { name:, path: }
    end
  end

  def retrieve_mesearement(value_quantity)
    if value_quantity.respond_to?(:coding)
      qty_coding = value_quantity.coding.first
      code = qty_coding&.code
      display = qty_coding&.display
      value = qty_coding&.extension&.first&.valueDecimal
      "#{value}. #{display} (#{code})".delete_prefix('. ')
    else
      value = value_quantity&.value
      code = value_quantity&.code
      unit = value_quantity&.unit
      "#{value} #{unit.presence || code}"
    end
  end

  def retrieve_members(member_references, bundle_entries)
    member_references.map do |member_ref|
      resource_type, id = member_ref.reference.split('/')
      ref_resource = bundle_entries.find { |entry| entry.resourceType == resource_type && entry.id == id }
      next unless ref_resource

      Observation.new(ref_resource, bundle_entries)
    end
  end

  def categories
    @categories = @fhir_resource.category.map do |category|
      code = category.coding.first.code
      display = category.coding.first.display
      { code:, display: }
    end
  end
end
