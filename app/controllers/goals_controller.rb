# app/controllers/goals_controller.rb
class GoalsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/goals
  def index
    @pagy, @goals = pagy_array(fetch_goals(params[:patient_id]), items: 5)
    flash.now[:notice] = I18n.t('controllers.goals.no_goals') if @goals.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @goals = []
  end

  private

  def fetch_goals(patient_id)
    goals = Goal.filter_by_patient_id(patient_id)
    return goals unless Goal.expired? || goals.blank?

    entries = retrieve_current_patient_resources
    fhir_goals = cached_resources_type('Goal')

    if fhir_goals.blank?
      Rails.logger.info('Goals not found in patient record cache, fetching directly')
      entries = fetch_goals_by_patient(patient_id, 500, Goal.updated_at)
      fhir_goals = entries.select { |entry| entry.resourceType == 'Goal' }
    end

    # Get other resources for reference resolution
    other_resources = retrieve_other_resources

    # Combine entries and create Goal objects
    entries = (entries + other_resources).uniq
    fhir_goals.each { |entry| Goal.new(entry, entries) }

    Goal.filter_by_patient_id(patient_id)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Goals:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))

    raise "Error fetching or parsing patient's goals. Check the log for detail."
  end
end
