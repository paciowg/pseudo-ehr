# app/controllers/transition_of_cares_controller.rb
class TransitionOfCaresController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/transition_of_cares
  def index
    @pagy, @tocs = pagy_array(fetch_and_cache_tocs, items: 10)
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patients_path
  end

  # PUT /patients/:patient_id/transition_of_cares
  def create_toc_resource
    modified_resource = modify_resource_with_selected
    create_new_toc_resource(modified_resource, method: :put, id: modified_resource.id.to_s)
  end

  private


  def modify_resource_with_selected

    # selected_ids are the resources the user selected to be in the TOC 
    selected_ids = params[:toc_selected_resource_ids].split(',')
    
    # original_resource is the TOC we are updating
    original_resource = FHIR.from_contents(JSON.parse(params[:original_toc_resource].to_json))
    
    # Note: This approach does not account for when there are no resources from that category
    # that were previously selected. Will need to adapt approach from 'create' for the "else".
    if original_resource.section.present?
      original_resource.section.each do |section|
        next if section.title.nil? || section.title == '--'
          if !section.entry.nil?
            list_references = section.entry

            if (!list_references[0].nil? ) 
              type_of_resource = list_references[0].reference.split("/")[0] 
            end

            if (selected_ids.length > 0 ) 
              type_of_resources_selected = selected_ids[0].split("/")[0]
            end

            # Since we will only need the one section to update, ensure the section we have
            # is the same as the resources we have selected to use to update with
            # and return if not
            if (type_of_resource == type_of_resources_selected)
              list_references.each do |reference_obj|
                reference = reference_obj.reference
                if selected_ids.include?(reference)
                  # TOC already includes this resource, just remove id from full_ids list
                  removed = selected_ids.delete(reference)
        
                
                else
                  # if the id of the condition is not in the list, remove it (it was not selected)
                  # Note: more efficient way to delete from fhir object?
                  resource_json = JSON.parse(original_resource.to_json)
                  json_section_arr = resource_json["section"]
                  json_section_arr.each do |json_section|
                    if json_section["title"].to_s == section.title.to_s
                      json_entry_list = json_section['entry']
                      str_obj = {"reference" => reference.to_s}
                      index = json_entry_list.find_index(str_obj)
                      json_entry_list.delete_at(index)
                    end
                  end
                  original_resource = FHIR.from_contents(resource_json.to_json)
                  
                end
              end

              # if there are still remaining ones in the selected list for this type,
              # add those references in to the final TOC. (This case would happen when
              # a person selects a resource available that is not yet in the TOC).
              selected_ids.each do |new_id|
                new_resource = FHIR::Reference.new(
                  {
                    "resourceType": type_of_resource.to_s,
                    "reference": new_id.to_s
                  }
                )
                section.entry.push(new_resource)
                selected_ids.delete(new_id.to_s)
              end
            end
          end
        end
    end
    original_resource
  end

  def fetch_and_cache_tocs
    Rails.cache.fetch(cache_key_for_patient_tocs(params[:patient_id])) do
      entries = retrieve_current_patient_resources
      fhir_compositions = filter_doc_refs_or_compositions_by_category(cached_resources_type('Composition'))

      if fhir_compositions.blank?
        entries = fetch_compositions_by_patient(patient_id)
        fhir_compositions = entries.select { |entry| entry.resourceType == 'Composition' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_compositions.map { |entry| Composition.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing TOC Composition:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise 'Error fetching or parsing TOC Composition. Check logs for detail.'
    end
  end
end
