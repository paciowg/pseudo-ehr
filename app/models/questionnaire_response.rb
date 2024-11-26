# QuestionnaireResponse Model
class QuestionnaireResponse < Resource
  attr_reader :id, :name, :description, :questionnaire, :status, :author, :date, :formatted_date, :items, :fhir_resource

  def initialize(fhir_questionnaire_response, bundle_entries)
    @fhir_resource = fhir_questionnaire_response
    @id = fhir_questionnaire_response.id
    @name = find_name
    @description = find_description
    @questionnaire = fhir_questionnaire_response.questionnaire
    @status = fhir_questionnaire_response.status
    @author = parse_provider_name(@fhir_resource.author, bundle_entries)
    @date = fhir_questionnaire_response.authored
    @formatted_date = parse_date(fhir_questionnaire_response.authored)
    parse_items(fhir_questionnaire_response.item)
  end

  private

  def find_name
    name_extension = @fhir_resource.meta.extension.find { |ext| ext.url.include?('name') }
    # name_extension ||= @fhir_resource._questionnaire.extension.find do |ext|
    #   ext.url.include?('name') || ext.url.include?('display')
    # end

    name_extension.present? ? name_extension.value : @fhir_resource.id
  end

  def find_description
    description_extension = @fhir_resource.meta.extension.find { |ext| ext.url.include?('description') }
    # description_extension ||= @fhir_resource._questionnaire.extension.find { |ext| ext.url.include?('description') }
    description_extension.present? ? description_extension.value : 'No description'
  end

  def parse_items(fhir_items)
    @items ||= []
    fhir_items.each do |fhir_item|
      item = {}
      item[:link_id] = fhir_item.linkId || '--'
      item[:text] = fhir_item.text || '--'
      item[:answers] = fhir_item.answer.map do |answer|
        coding = answer.valueCoding || answer.valueQuantity
        next if coding.nil?

        { code: coding.code, system: coding.system, display: coding.display || "#{coding.value} #{coding.unit}" }
      end.compact
      @items << item

      parse_items(fhir_item.item) if fhir_item.item.present?
    end
  end
end
