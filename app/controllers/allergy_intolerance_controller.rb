# app/controllers/allergy_intolerance_controller.rb
class AllergyIntolerancesController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/allergyintolerance
  def index
    @pagy, @allergyintolerances = pagy_array(fetch_and_cache_allergy_intolerances(params[:patient_id]),
                                             items: 10)
    flash.now[:notice] = 'Patient has no allergy intolerances' if @allergyintolerances.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @allergyintolerances = []
  end

  private

  def fetch_and_cache_allergy_intolerances(patient_id)
    Rails.cache.fetch(cache_key_for_patient_allergy_intolerances(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_allergy_intolerances = cached_resources_type('AllergyIntolerance')

      if fhir_allergy_intolerances.blank?
        entries = fetch_allergy_intolerances_by_patient(patient_id)
        fhir_allergy_intolerances = entries.select { |entry| entry.resourceType == 'AllergyIntolerance' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      allergyintolerances = fhir_allergy_intolerances.map { |entry| AllergyIntolerance.new(entry, entries) }
      allergyintolerances.sort_by { |aller| aller.onset_date_time || aller.recorded_date || '' }.reverse
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing AllergyIntolerance:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching or parsing patient's allergy intolerances. Check the log for detail."
    end
  end
end
