# frozen_string_literal: true

# CarePlan Model
class CarePlan < Resource
  attr_reader :id, :fhir_resource, :status, :intent, :category, :activities

  def initialize(fhir_care_plan, bundle_entries)
    @fhir_resource = fhir_care_plan
    @id = fhir_care_plan.id
    @status = fhir_care_plan.status
    @intent = fhir_care_plan.intent
    @category = read_category(fhir_care_plan.category)
    @activities = read_activities(bundle_entries)
  end

  private

  def read_category(category)
    category&.map { |c| read_codeable_concept(c) }&.join(', ')
  end

  def read_codeable_concept(codeable_concept)
    c = codeable_concept&.coding&.first
    c&.display ? c.display : c&.code&.gsub('-', ' ')&.titleize
  end

  # TODO: Make it more granular to cover various possible resource Type
  def read_activities(bundle_entries)
    @fhir_resource.activity&.map do |activity|
      resource = get_object_from_bundle(activity.reference, bundle_entries)
      next unless resource

      resource.resourceType.constantize.new(resource, bundle_entries)
    end&.compact
  end
end
