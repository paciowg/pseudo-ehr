# Observation Model
class Observation < Resource
  attr_reader :id, :status, :category, :domain, :code, :effective_date_time,
              :performer, :derived_from, :measurement, :measurement_interpretation,
              :location, :organization, :members, :components, :fhir_resource, :patient_id,
              :patient, :reference_range, :body_site, :local_mentod, :device, :notes

  def initialize(fhir_observation, bundle_entries = [])
    @fhir_resource = fhir_observation
    @id = fhir_observation.id
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = fhir_observation.status
    @effective_date_time = fhir_observation.effectiveDateTime
    @category = retrieve_category
    @domain = retrieve_domain
    @code = retrieve_code&.gsub('\n', '')&.gsub('\t', '')
    @performer = fhir_observation.performer&.map do |performer|
                   parse_provider_name(performer, bundle_entries)
                 end&.join(',').presence || '--'
    @organization = retrieve_org(fhir_observation.performer, bundle_entries)
    @derived_from = retrieve_derived_from(fhir_observation.derivedFrom)
    @measurement = retrieve_mesearement
    @measurement_interpretation = fhir_observation.try(:interpretation)&.map(&:text)&.join(', ').presence || '--'
    @location = retrieve_location(bundle_entries)
    @members = retrieve_members(fhir_observation.hasMember, bundle_entries)
    @components = retrieve_components(fhir_observation.component)
    @body_site = retrieve_body_site
    @local_method = retrieve_method
    @device = @fhir_resource.device.try(:display).presence || '--'
    # TODO: parse ref range and update app/views/shared/_observation_modal.html.erb
    @reference_range = '--'
    # TODO: parse note and update app/views/shared/_observation_modal.html.erb
    @notes = []

    self.class.update(self)
  end

  def collection?
    @members.present?
  end

  def value_quantity?
    @fhir_resource.valueQuantity.present?
  end

  def components?
    @components.present?
  end

  def raw_code
    @fhir_resource.code&.coding&.first&.code
  end

  def effective
    parse_date(@effective_date_time)
  end

  def issued
    parse_date(@fhir_resource.issued)
  end

  def min_ref_range
    @fhir_resource.referenceRange&.first&.low&.value&.to_f
  end

  def max_ref_range
    @fhir_resource.referenceRange&.first&.high&.value&.to_f
  end

  def self.collections(observations)
    observations.select(&:collection?)
                .sort_by { |observation| observation&.effective_date_time || '' }
                .reverse
  end

  def self.format_domain(domain_code)
    # Domain can be a comma separated list
    domain_code.split(/,\s+/).map do |domain|
      display = pfe_domain_dict[domain] || category_dict[domain]
      display.present? ? "#{display} (#{domain})" : domain
    end.join(', ')
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
    category_codes = categories.reject do |cat|
      cat[:system] == 'http://hl7.org/fhir/us/pacio-pfe/CodeSystem/pfe-category-cs'
    end.pluck(:code).sort

    formatted_categories = category_codes.map do |code|
      self.class.internal_category_dict[code] || self.class.category_dict[code] || code
    end.compact.uniq

    formatted_categories.join(', ').presence || 'Other'
  end

  def retrieve_domain
    domains = categories.select { |cat| cat[:system] == 'http://hl7.org/fhir/us/pacio-pfe/CodeSystem/pfe-category-cs' }
    domains.map { |d| d[:display] ? "#{d[:display]} (#{d[:code]})" : d[:code] }.join(', ')
  end

  def retrieve_code
    obs_code = @fhir_resource.code&.coding&.first
    code = obs_code&.code
    display = obs_code&.display

    display.present? ? "#{display} (#{code})" : (code.presence || '--')
  end

  def retrieve_body_site
    site = @fhir_resource.bodySite&.coding&.first
    code = site&.code
    display = site&.display

    display.present? ? "#{display} (#{code})" : (code.presence || '--')
  end

  def retrieve_method
    meth = @fhir_resource.try(:local_method).try(:coding).try(:first)
    code = meth.try(:code)
    display = meth.try(:display)

    display.present? ? "#{display} (#{code})" : (code.presence || '--')
  end

  def retrieve_org(performer, bundle_entries)
    role = performer.find { |elmt| elmt.reference.start_with?('PractitionerRole') }
    return 'Not provided' if role.blank?

    resource_type, id = role.reference.split('/')
    ref_resource = bundle_entries.find { |entry| entry.resourceType == resource_type && entry.id == id }

    ref_resource.try(:organization)&.display || 'Not provided'
  end

  def retrieve_location(bundle_entries)
    location_ext = @fhir_resource.extension.find { |ext| ext.url == 'http://hl7.org/fhir/StructureDefinition/event-location' }
    return 'Not provided' if location_ext.blank?

    location_ref = location_ext.valueReference&.reference
    resource_type, id = location_ref&.split('/')
    ref_resource = bundle_entries.find { |entry| entry.resourceType == resource_type && entry.id == id }

    ref_resource&.name || 'Not provided'
  end

  def retrieve_derived_from(fhir_derived_from)
    return [] if @patient_id.blank? || fhir_derived_from.blank?

    fhir_derived_from&.map do |elmt|
      resource_type, id = elmt.reference.split('/')
      reference = "#{resource_type}/#{id}"
      name = "#{resource_type}-#{id} "
      path = "/patients/#{@patient_id}/#{resource_type.downcase}s/#{id}"
      { name:, path:, reference: }
    end
  end

  def retrieve_mesearement
    value_quantity = @fhir_resource.valueQuantity.presence || @fhir_resource.valueCodeableConcept
    if @fhir_resource.valueString.present?
      @fhir_resource.valueString
    elsif @fhir_resource.valueDateTime.present?
      parse_date(@fhir_resource.valueDateTime)
    elsif value_quantity.respond_to?(:coding)
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
    end.compact
  end

  def categories
    @categories = @fhir_resource.category.map do |category|
      code = category.coding.first&.code
      display = category.coding.first&.display
      system = category.coding.first&.system
      { code:, display:, system: }
    end.compact
  end

  def retrieve_components(components)
    return [] if components.blank?

    components.map do |component|
      code = component.code&.coding&.first
      display = code&.display
      code_val = code&.code
      {
        code: display.present? ? "#{display} (#{code_val})" : (code_val.presence || '--'),
        value_quantity: component.valueQuantity
      }
    end
  end
end
