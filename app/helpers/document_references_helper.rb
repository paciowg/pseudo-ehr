# app/helpers/document_references_helper.rb
module DocumentReferencesHelper
  def extract_composition_title(bundle)
    return '' if bundle.blank?

    composition_entry = bundle.entry.to_a.find { |entry| entry.resource.is_a?(FHIR::Composition) }
    composition = composition_entry&.resource

    composition&.title.to_s
  end
end
