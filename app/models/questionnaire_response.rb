# QuestionnaireResponse Model
class QuestionnaireResponse < Resource
  attr_reader :id, :name, :description, :questionnaire, :questionnaire_title, :status,
              :subject, :encounter, :author, :source, :date, :formatted_date,
              :items, :fhir_resource, :based_on, :part_of, :identifier

  def initialize(fhir_questionnaire_response, bundle_entries)
    @fhir_resource = fhir_questionnaire_response
    @id = fhir_questionnaire_response.id
    @identifier = parse_identifier(fhir_questionnaire_response.identifier)
    @name = find_name
    @description = find_description
    @questionnaire = fhir_questionnaire_response.questionnaire
    @questionnaire_title = extract_questionnaire_title
    @status = fhir_questionnaire_response.status
    @subject = parse_reference(fhir_questionnaire_response.subject, bundle_entries)
    @encounter = parse_reference(fhir_questionnaire_response.encounter, bundle_entries)
    @author = parse_provider_name(fhir_questionnaire_response.author, bundle_entries)
    @source = parse_reference(fhir_questionnaire_response.source, bundle_entries)
    @date = fhir_questionnaire_response.authored
    @formatted_date = parse_date(fhir_questionnaire_response.authored)
    @based_on = parse_references(fhir_questionnaire_response.basedOn, bundle_entries)
    @part_of = parse_references(fhir_questionnaire_response.partOf, bundle_entries)
    @items = []
    parse_items(fhir_questionnaire_response.item)
    organize_items_hierarchically
  end

  # Returns a categorized view of items for better organization in the UI
  def categorized_items
    @items.group_by { |item| item[:category] || 'Uncategorized' }
  end

  # Returns items organized by section for better display
  def sections
    @items.select { |item| item[:type] == 'group' }
  end

  # Returns only question items (not groups)
  def questions
    @items.select { |item| item[:type] == 'question' }
  end

  # Returns a flattened view of all questions with their answers
  def flattened_questions
    flatten_items(@items)
  end

  private

  def parse_identifier(identifiers)
    return [] if identifiers.blank?

    identifiers.map do |identifier|
      {
        system: identifier.system,
        value: identifier.value,
        type: identifier.type&.coding&.first&.display || identifier.type&.text
      }
    end
  end

  def extract_questionnaire_title
    return @name if @questionnaire.blank?

    # Try to extract a title from the questionnaire reference
    if @questionnaire.include?('|')
      parts = @questionnaire.split('|')
      return parts.last if parts.size > 1
    end

    # Extract the last part of the URL as a fallback
    uri = begin
      URI.parse(@questionnaire)
    rescue StandardError
      nil
    end
    return File.basename(uri.path) if uri && uri.path.present?

    @name
  end

  def find_name
    # Try to find name in extensions
    name_extension = @fhir_resource.meta&.extension&.find { |ext| ext.url.include?('name') }
    return name_extension.value if name_extension.present?

    # Try to extract from questionnaire reference
    return extract_questionnaire_title if @fhir_resource.questionnaire.present?

    # Fallback to ID
    @fhir_resource.id
  end

  def find_description
    # Try to find description in extensions
    description_extension = @fhir_resource.meta&.extension&.find { |ext| ext.url.include?('description') }
    return description_extension.value if description_extension.present?

    # Try to find in contained resources
    if @fhir_resource.contained.present?
      questionnaire = @fhir_resource.contained.find { |resource| resource.resourceType == 'Questionnaire' }
      return questionnaire.description if questionnaire&.description.present?
    end

    'No description available'
  end

  def parse_references(references, bundle_entries)
    return [] if references.blank?

    references.map do |reference|
      parse_reference(reference, bundle_entries)
    end.compact
  end

  def parse_reference(reference, bundle_entries)
    return nil if reference.blank?

    reference_string = reference.reference
    display = reference.display

    # If no reference string but display is present, return simple hash with display
    if reference_string.blank? && display.present?
      return {
        reference: nil,
        type: nil,
        id: nil,
        display: display,
        resource: nil
      }
    end

    # Return nil if no reference string
    return nil if reference_string.blank?

    # Parse reference string to get resource type and ID
    parts = reference_string.split('/')
    resource_type = parts.size > 1 ? parts[-2] : nil
    resource_id = parts.last

    # Try to find the referenced resource in the bundle
    resource = nil
    if bundle_entries.present?
      resource = bundle_entries.find do |entry|
        entry.resourceType == resource_type && entry.id == resource_id
      end
    end

    # For provider-type resources, use parse_provider_name
    if %w[Practitioner Patient RelatedPerson Organization PractitionerRole].include?(resource_type)
      {
        reference: reference_string,
        type: resource_type,
        id: resource_id,
        display: parse_provider_name(reference, bundle_entries),
        resource: resource
      }
    elsif resource
      # For other resources, use similar logic as in Procedure model
      case resource_type
      when 'Condition'
        condition = Condition.new(resource, bundle_entries)
        {
          reference: reference_string,
          type: resource_type,
          id: resource_id,
          display: condition.code,
          resource: condition
        }
      when 'Observation'
        observation = Observation.new(resource, bundle_entries)
        {
          reference: reference_string,
          type: resource_type,
          id: resource_id,
          display: observation.code,
          resource: observation
        }
      when 'DiagnosticReport'
        diagnostic_report = DiagnosticReport.new(resource, bundle_entries)
        {
          reference: reference_string,
          type: resource_type,
          id: resource_id,
          display: diagnostic_report.code,
          resource: diagnostic_report
        }
      when 'Procedure'
        procedure = Procedure.new(resource, bundle_entries)
        {
          reference: reference_string,
          type: resource_type,
          id: resource_id,
          display: procedure.code,
          resource: procedure
        }
      when 'CarePlan'
        care_plan = CarePlan.new(resource, bundle_entries)
        {
          reference: reference_string,
          type: resource_type,
          id: resource_id,
          display: care_plan.category,
          resource: care_plan
        }
      when 'ServiceRequest'
        service_request = ServiceRequest.new(resource, bundle_entries)
        {
          reference: reference_string,
          type: resource_type,
          id: resource_id,
          display: service_request.code,
          resource: service_request
        }
      when 'DocumentReference'
        # DocumentReference requires pdf and pdf_binary_id parameters
        # Since we don't have those here, we'll just return the basic info
        {
          reference: reference_string,
          type: resource_type,
          id: resource_id,
          display: resource.type&.coding&.first&.display || resource.id,
          resource: nil
        }
      else
        # For other resource types, return basic info
        {
          reference: reference_string,
          type: resource_type,
          id: resource_id,
          display: display || resource_id,
          resource: resource
        }
      end
    else
      # If resource not found in bundle, return basic info
      {
        reference: reference_string,
        type: resource_type,
        id: resource_id,
        display: display || reference_string,
        resource: nil
      }
    end
  end

  def parse_items(fhir_items, parent_link_id = nil, level = 0)
    return if fhir_items.blank?

    fhir_items.each do |fhir_item|
      item = {
        link_id: fhir_item.linkId || '--',
        text: fhir_item.text || '--',
        parent_link_id: parent_link_id,
        level: level,
        type: fhir_item.item.present? ? 'group' : 'question',
        answers: [],
        children: []
      }

      # Parse answers if present
      if fhir_item.answer.present?
        item[:answers] = fhir_item.answer.map do |answer|
          parse_answer(answer)
        end.compact
      end

      # Add to items array
      @items << item

      # Parse nested items recursively
      parse_items(fhir_item.item, fhir_item.linkId, level + 1) if fhir_item.item.present?
    end
  end

  def parse_answer(answer)
    result = { value_type: nil, value: nil, display: '--' }

    # Handle different value types
    if answer.valueBoolean.present?
      result[:value_type] = 'boolean'
      result[:value] = answer.valueBoolean
      result[:display] = answer.valueBoolean ? 'Yes' : 'No'
    elsif answer.valueDecimal.present?
      result[:value_type] = 'decimal'
      result[:value] = answer.valueDecimal
      result[:display] = answer.valueDecimal.to_s
    elsif answer.valueInteger.present?
      result[:value_type] = 'integer'
      result[:value] = answer.valueInteger
      result[:display] = answer.valueInteger.to_s
    elsif answer.valueDate.present?
      result[:value_type] = 'date'
      result[:value] = answer.valueDate
      result[:display] = answer.valueDate
    elsif answer.valueDateTime.present?
      result[:value_type] = 'dateTime'
      result[:value] = answer.valueDateTime
      result[:display] = parse_date(answer.valueDateTime)
    elsif answer.valueTime.present?
      result[:value_type] = 'time'
      result[:value] = answer.valueTime
      result[:display] = answer.valueTime
    elsif answer.valueString.present?
      result[:value_type] = 'string'
      result[:value] = answer.valueString
      result[:display] = answer.valueString
    elsif answer.valueUri.present?
      result[:value_type] = 'uri'
      result[:value] = answer.valueUri
      result[:display] = answer.valueUri
    elsif answer.valueAttachment.present?
      result[:value_type] = 'attachment'
      result[:value] = answer.valueAttachment
      result[:display] = answer.valueAttachment.title || 'Attachment'
      result[:content_type] = answer.valueAttachment.contentType
      result[:data] = answer.valueAttachment.data
      result[:url] = answer.valueAttachment.url
    elsif answer.valueCoding.present?
      result[:value_type] = 'coding'
      result[:value] = answer.valueCoding
      result[:code] = answer.valueCoding.code
      result[:system] = answer.valueCoding.system
      result[:display] = answer.valueCoding.display || answer.valueCoding.code
    elsif answer.valueQuantity.present?
      result[:value_type] = 'quantity'
      result[:value] = answer.valueQuantity
      result[:display] = "#{answer.valueQuantity.value} #{answer.valueQuantity.unit}"
      result[:code] = answer.valueQuantity.code
      result[:system] = answer.valueQuantity.system
    elsif answer.valueReference.present?
      result[:value_type] = 'reference'
      result[:value] = answer.valueReference
      result[:display] = answer.valueReference.display || answer.valueReference.reference
      result[:reference] = answer.valueReference.reference
    else
      # No recognized value type
      return nil
    end

    result
  end

  def organize_items_hierarchically
    # Create a map of items by link_id for quick lookup
    items_map = {}
    @items.each do |item|
      items_map[item[:link_id]] = item
    end

    # Organize items into a hierarchical structure
    @items.each do |item|
      if item[:parent_link_id].present? && items_map[item[:parent_link_id]].present?
        parent = items_map[item[:parent_link_id]]
        parent[:children] << item
      end
    end
  end

  def flatten_items(items, result = [])
    items.each do |item|
      result << item if item[:type] == 'question'

      flatten_items(item[:children], result) if item[:children].present?
    end

    result
  end
end
