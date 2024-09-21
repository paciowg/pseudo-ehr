# NutritionOrder Model
class NutritionOrder < Resource
  attr_reader :id, :status, :intent, :date, :orderer,
    :excluded_food, :allergies, :oral_diet, :supplement, :fhir_resource

  def initialize(fhir_nutrition_order, bundle_entries = [])
    @id = fhir_nutrition_order.id
    @fhir_resource = fhir_nutrition_order
    @status = fhir_nutrition_order.status
    @intent = fhir_nutrition_order.intent
    @date = fhir_nutrition_oder.dateTime
    @oderer = retrieve_orderer_name(fhir_nutrition_oder.orderer, bundle_entries)
    @excluded_food = retrieve_excluded_food(fhir_nutrition_oder.excludeFoodModifier)
    @allergies = retrieve_allergies(fhir_nutrition_oder.allergyIntolerance, bundle_entries)
    # @category = read_category(fhir_nutrition_order.category)
    # @code = coding_string(fhir_nutrition_order.code&.coding)
    # @priority = fhir_nutrition_order.priority
    # @occurence = parse_date(fhir_nutrition_order.occurrenceDateTime)
    # @authored_on = parse_date(fhir_nutrition_order.authoredOn)
    # @performer_name = fhir_nutrition_order.performer&.first&.display
    # @performer_reference = fhir_nutrition_order.performer.first&.reference
    # @requester = read_requester_name(fhir_nutrition_order.requester, bundle_entries)
  end

  private

  def retrieve_orderer_name(orderer, bundle_entries)
    orderer.map do |orderer_ref|
      name = orderer_ref.display
      return name if name.present?

      resource_type, id = orderer_ref.reference.split('/')
      ref_resource = bundle_entries.find { |entry| entry.resourceType == resource_type && entry.id == id }

      name = ref_resource.try(:practitioner)&.display
      if name
        role = ref_resource.try(:code)&.first&.coding&.first&.display

        return role.present? ? "#{name} | #{role}" : name
      end

      fhir_name_array = ref_resource.try(:name) || []
      format_name(fhir_name_array) => { first_name:, last_name: }
      "#{first_name} #{last_name}"
    end.join(', ')
  end

  def retrieve_excluded_food(exclude_food_modifier)
    modifiers = exclude_food_modifier.map{ |modifier| modifier.coding.first&.display }.compact

    modifiers.present? ? modifiers.join(', ') : 'none provided'
  end

  def retrieve_allergies(allergy_intolerance, bundle_entries)
    allergy_intolerance.map do |elmt|
      resource_type, resource_id = elmt.reference.split('/')
      ref_resource = bundle_entries.find { |entry| entry.resourceType == resource_type && entry.id == id }

      AllergyIntolerance.new(ref_resource, bundle_entries) if ref_resource.present?

    end
  end

  # def read_category(category)
  #   category&.map { |c| read_codeable_concept(c) }&.join(', ')
  # end

  # def read_codeable_concept(codeable_concept)
  #   c = codeable_concept&.coding&.first
  #   c&.display ? c.display : c&.code&.gsub('-', ' ')&.titleize
  # end

  # def read_requester_name(requester_ref, bundle_entries)
  #   resource_type, resource_id = requester_ref.reference.split('/')
  #   requester_resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }
  #   return '--' unless requester_resource

  #   case resource_type
  #   when 'Practitioner', 'Patient', 'RelatedPerson'
  #     format_name(requester_resource.name) => { first_name:, last_name: }
  #     "#{first_name} #{last_name}"
  #   when 'Organization'
  #     requester_resource.name
  #   when 'PractitionerRole'
  #     name = requester_resource.practitioner.display
  #     return name if name

  #     practioner_id = requester_resource.practitioner.reference.split('/').last
  #     practitioner = bundle_entries.find { |res| res.resourceType == 'Practitioner' && res.id == practioner_id }
  #     format_name(practitioner.name) => { first_name:, last_name: }
  #     "#{first_name} #{last_name}"
  #   end
  # end
end
