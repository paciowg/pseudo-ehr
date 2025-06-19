# NutritionOrder Model
class NutritionOrder < Resource
  attr_reader :id, :status, :intent, :date, :orderer, :category, :fhir_resource,
              :exclude_food, :allergies, :oral_diet, :supplements, :patient_id,
              :patient

  def initialize(fhir_nutrition_order, bundle_entries = [])
    @id = fhir_nutrition_order.id
    @fhir_resource = fhir_nutrition_order
    @patient_id = @fhir_resource.patient&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = fhir_nutrition_order.status
    @intent = fhir_nutrition_order.intent&.capitalize
    @date = fhir_nutrition_order.dateTime
    @orderer = parse_provider_name(fhir_nutrition_order.orderer, bundle_entries)
    @supplements = fhir_nutrition_order.supplement&.map { |supp| parse_supplement(supp) }&.compact
    @oral_diet = parse_oral_diet(fhir_nutrition_order.oralDiet)
    @exclude_food = retrieve_excluded_food(fhir_nutrition_order.excludeFoodModifier)
    @allergies = parse_allergies(fhir_nutrition_order.allergyIntolerance, bundle_entries)

    self.class.update(self)
  end

  private

  def parse_oral_diet(fhir_oral_diet)
    return {} unless fhir_oral_diet

    oral_diet = {}
    oral_diet[:type] = fhir_oral_diet.type&.first&.coding&.map(&:display)&.join(', ').presence || '--'
    oral_diet[:schedule] = parse_schedule(fhir_oral_diet.schedule&.first)
    oral_diet[:fluid_consistency] =
      fhir_oral_diet.fluidConsistencyType&.first&.coding&.map(&:display)&.join(', ').presence || '--'
    oral_diet[:instruction] = fhir_oral_diet.instruction || '--'

    oral_diet
  end

  def parse_supplement(fhir_supp)
    return unless fhir_supp

    supplement = {}
    supplement[:type] = fhir_supp.type&.coding&.map(&:display)&.join(', ').presence || '--'
    supplement[:schedule] = parse_schedule(fhir_supp.schedule&.first)
    supplement
  end

  def parse_schedule(fhir_schedule)
    repeat = fhir_schedule&.repeat
    return '--' unless repeat

    schedule_start = repeat.boundsPeriod&.start
    frequency = repeat.frequency
    frequency_max = repeat.frequencyMax
    frequency = frequency_max ? "#{frequency}-#{frequency_max}x" : "#{frequency}x"
    period = repeat.period
    period = nil if period == 1
    period_unit = { 'd' => 'day', 'w' => 'week' }[repeat.periodUnit]
    schedule = "#{frequency} every #{period} #{period_unit}"
    schedule += " starting #{schedule_start}" if schedule_start.present?

    schedule
  end

  def retrieve_excluded_food(exclude_food_modifier)
    modifiers = exclude_food_modifier.map { |modifier| modifier.coding.first&.display }.compact

    modifiers.present? ? modifiers.join(', ') : 'none provided'
  end

  def parse_allergies(allergy_intolerance, bundle_entries)
    allergies = []

    allergy_intolerance&.each do |elmt|
      resource_type, resource_id = elmt.reference.split('/')
      ref_resource = bundle_entries.find { |entry| entry.resourceType == resource_type && entry.id == resource_id }
      next unless ref_resource

      allergies << AllergyIntolerance.new(ref_resource, bundle_entries)
    end

    allergies
  end
end
