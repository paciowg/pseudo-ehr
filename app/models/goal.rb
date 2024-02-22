# frozen_string_literal: true

# Goal Model
class Goal < Resource
  attr_reader :id, :lifecycle_status, :achievement_status, :category,
              :description, :targets, :addresses, :note, :author, :fhir_resource

  def initialize(fhir_goal, bundle_entries)
    @fhir_resource = fhir_goal
    @id = fhir_goal.id
    @lifecycle_status = fhir_goal.lifecycleStatus&.capitalize
    @achievement_status = fhir_goal.achievementStatus&.coding&.first&.code&.humanize
    @category = retrieve_categories
    @description = fhir_goal.try(:description)&.text
    @targets = retrieve_targets
    @addresses = retrieve_addresses(fhir_goal.subject)
    @note = fhir_goal.try(:note)&.first&.text || '--'
    @author = retrieve_author(bundle_entries)
  end

  def note_time
    parse_date(@fhir_resource.try(:note)&.first&.time)
  end

  private

  def retrieve_categories
    @fhir_resource.category.map do |cat|
      code = cat.coding.first&.code
      display = cat.coding.first&.display

      formatted_cat = "#{display} (#{code})"
      if formatted_cat.strip.start_with?('(')
        formatted_cat.strip.delete_prefix('(').delete_suffix(')').underscore.humanize.titleize
      else
        formatted_cat
      end
    end.join(', ')
  end

  def retrieve_targets
    @fhir_resource.target.map do |target|
      measure = target.measure&.coding&.first&.code
      measure = measure.present? ? "LOINC##{measure}" : '--'
      detail_value = target.detailQuantity&.value
      detail_code = target.detailQuantity&.code
      detail = "#{detail_value} #{detail_code}".presence || '--'
      due_date = target.dueDate
      description = target.try(:detailString)

      { measure:, detail:, due_date:, description: }
    end
  end

  def retrieve_addresses(patient_ref)
    patient_id = patient_ref.reference.split('/').last
    @fhir_resource.addresses.map do |item|
      name = item.reference
      resource_type, id = name.split('/')
      path = "/patients/#{patient_id}/#{resource_type.downcase}s/#{id}"
      { name:, path: }
    end
  end

  def retrieve_author(bundle_entries)
    author_ref = @fhir_resource.try(:note)&.first&.authorReference || @fhir_resource.try(:expressedBy)
    return '--' if author_ref.blank?

    return author_ref.display if author_ref&.display.present?

    resource_type, id = author_ref.reference&.split('/')
    resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == id }
    return '--' if resource.blank?

    name = '--'
    if resource_type == 'Practitioner'
      format_name(resource.name) => { first_name:, last_name: }
      name = "#{first_name} #{last_name}"
    elsif resource_type == 'PractitionerRole'
      name = resource.practitioner&.display || '--'
    end
    name
  end
end
