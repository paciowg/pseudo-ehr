# app/controllers/goals_controller.rb
class GoalsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/goals
  def index
    @pagy, @goals = pagy_array(fetch_and_cache_goals(params[:patient_id]),
                               items: 5)
    flash.now[:notice] = 'Patient has no goals' if @goals.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @goals = []
  end

  private

  def fetch_and_cache_goals(patient_id)
    Rails.cache.fetch(cache_key_for_patient_goals(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_goals = cached_resources_type('Goal')

      if fhir_goals.blank?
        entries = fetch_goals_by_patient(patient_id)
        fhir_goals = entries.select { |entry| entry.resourceType == 'Goal' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_goals.map { |entry| Goal.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Goals:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))

      raise "Error fetching or parsing patient's goals. Check the log for detail."
    end
  end
end
