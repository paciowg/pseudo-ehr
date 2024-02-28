# frozen_string_literal: true

# Goal Model
class Goal < Resource
  attr_reader :id, :lifecycle_status, :achievement_status, :category,
              :description, :targets, :addresses, :notes, :author, :fhir_resource

  def initialize(fhir_goal, bundle_entries)
    @fhir_resource = fhir_goal
    @id = fhir_goal.id
    @lifecycle_status = fhir_goal.lifecycleStatus&.capitalize
    @achievement_status = fhir_goal.achievementStatus&.coding&.first&.code&.gsub('-', ' ')&.titleize
    @category = retrieve_categories
    @description = fhir_goal.try(:description)&.text
    @targets = retrieve_targets
    @addresses = retrieve_addresses(fhir_goal.subject)
    @notes = retrieve_notes(bundle_entries)
    @author = retrieve_author(bundle_entries, @fhir_resource.try(:expressedBy))
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

  def retrieve_notes(bundle_entries)
    fhir_notes = @fhir_resource.try(:note) || []
    fhir_notes.map do |fhir_note|
      note = fhir_note.text || '--'
      time = parse_date(fhir_note.time)
      author_ref = fhir_note.authorReference.presence
      author = retrieve_author(bundle_entries, author_ref)

      { note:, time:, author: }
    end.reverse
  end

  def retrieve_author(bundle_entries, author_ref)
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
