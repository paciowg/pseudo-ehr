# app/controllers/conditions_controller.rb
class ConditionsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/conditions
  def index
    @pagy, @conditions = pagy_array(fetch_and_cache_conditions(params[:patient_id]),
                                    items: 10)
    flash.now[:notice] = 'Patient has no conditions' if @conditions.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @conditions = []
  end

  private

  def fetch_and_cache_conditions(patient_id)
    Rails.cache.fetch(cache_key_for_patient_conditions(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_conditions = cached_resources_type('Condition')

      if fhir_conditions.blank?
        entries = fetch_conditions_by_patient(patient_id)
        fhir_conditions = entries.select { |entry| entry.resourceType == 'Condition' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      conditions = fhir_conditions.map { |entry| Condition.new(entry, entries) }
      conditions.sort_by { |cond| cond.onset_date_time || cond.recorded_date || '' }.reverse
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Condition:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching or parsing patient's conditions. Check the log for detail."
    end
  end
end
