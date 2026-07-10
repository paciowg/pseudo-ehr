# app/helpers/document_references_helper.rb
module DocumentReferencesHelper
  def extract_composition_title(bundle)
    composition_entry = bundle.entry.to_a.find { |entry| entry.resource.is_a?(FHIR::Composition) }
    composition = composition_entry&.resource

    composition&.title.presence
  end
end
