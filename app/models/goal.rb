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
    @addresses = retrieve_addresses(bundle_entries)
    @notes = retrieve_notes(bundle_entries)
    author_ref = @fhir_resource.try(:expressedBy)
    @author = author_ref.present? ? parse_provider_name(author_ref, bundle_entries) : '--'
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
      measure_code = target.measure&.coding&.first&.code
      measure_display = target.measure&.coding&.first&.display
      measure = if measure_display && measure_code
                  "#{measure_display} (#{measure_code})"
                elsif measure_code
                  "LOINC##{measure_code}"
                else
                  '--'
                end
      detail_value = target.detailQuantity&.value
      detail_code = target.detailQuantity&.code
      detail = "#{detail_value} #{detail_code}".presence || '--'
      due_date = target.dueDate
      description = target.try(:detailString)

      { measure:, detail:, due_date:, description: }
    end
  end

  def retrieve_addresses(bundle_entries)
    @fhir_resource.addresses.map do |item|
      resource_type, id = item.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == id }
      next unless resource

      case resource_type
      when 'Condition'
        Condition.new(resource, bundle_entries).code
      when 'Observation'
        Observation.new(resource, bundle_entries).code
      else
        next
      end
    end.compact
  end

  def retrieve_notes(bundle_entries)
    fhir_notes = @fhir_resource.try(:note) || []
    fhir_notes.map do |fhir_note|
      note = fhir_note.text || '--'
      time = parse_date(fhir_note.time)
      author_ref = fhir_note.authorReference.presence
      author = parse_provider_name(author_ref, bundle_entries)

      { note:, time:, author: }
    end.reverse
  end
end
