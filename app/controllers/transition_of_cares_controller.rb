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
    Rails.logger.info('Creating a new resource.')
    new_json_composition_resource = JSON.parse(params[:new_toc_resource].to_json)
    new_fhir_composition_resource = FHIR.from_contents(new_json_composition_resource)
    create_new_toc_resource(new_fhir_composition_resource, method: :put, id: new_fhir_composition_resource.id.to_s)
  end

  private

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
