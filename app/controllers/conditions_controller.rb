# app/controllers/conditions_controller.rb
class ConditionsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/conditions
  def index
    @pagy, @conditions = pagy_array(get_conditions(params[:patient_id]),
                                    items: 10)
    flash.now[:notice] = I18n.t('controllers.conditions.no_conditions') if @conditions.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @conditions = []
  end

  private

  def get_conditions(patient_id)
    conditions = Condition.filter_by_patient_id(patient_id)
    return sort_conditions(conditions) unless Condition.expired? || conditions.blank?

    entries = retrieve_current_patient_resources
    fhir_conditions = cached_resources_type('Condition')

    # Only fetch conditions directly if not found in patient record
    if fhir_conditions.blank?
      Rails.logger.info('Conditions not found in patient record cache, fetching directly')
      entries = fetch_conditions_by_patient(patient_id, 500, Condition.updated_at)
      fhir_conditions = entries.select { |entry| entry.resourceType == 'Condition' }
    end

    # Get other resources for reference resolution
    other_resources = retrieve_other_resources

    # Combine entries and create Condition objects
    entries = (entries + other_resources).uniq
    fhir_conditions.each { |entry| Condition.new(entry, entries) }

    conditions = Condition.filter_by_patient_id(patient_id)
    sort_conditions(conditions)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Condition:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Error fetching or parsing patient's conditions. Check the log for detail."
  end

  def sort_conditions(conditions)
    conditions.sort_by { |cond| cond.onset_date_time || cond.recorded_date || '' }.reverse
  end
end
