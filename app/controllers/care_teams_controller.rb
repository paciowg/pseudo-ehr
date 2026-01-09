# app/controllers/care_teams_controller.rb
class CareTeamsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/care_teams
  def index
    @care_teams = get_care_teams(params[:patient_id])
    flash.now[:notice] = I18n.t('controllers.care_teams.no_care_teams') if @care_teams.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @care_teams = []
  end

  private

  def get_care_teams(patient_id)
    care_teams = CareTeam.filter_by_patient_id(patient_id)
    return care_teams unless CareTeam.expired? || care_teams.blank?

    entries = retrieve_current_patient_resources
    fhir_care_teams = cached_resources_type('CareTeam')
    # Only fetch care teams directly if not found in patient record
    if fhir_care_teams.blank?
      Rails.logger.info('Care teams not found in patient record cache, fetching directly')
      entries = fetch_care_teams_by_patient(patient_id, 500, CareTeam.updated_at)
      fhir_care_teams = entries.select { |entry| entry.resourceType == 'CareTeam' }
    end

    # Get other resources for reference resolution
    other_resources = retrieve_other_resources

    # Combine entries and create CareTeam objects
    entries = (entries + other_resources).uniq
    fhir_care_teams.each { |entry| CareTeam.new(entry, entries) }

    CareTeam.filter_by_patient_id(patient_id)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Care team:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Error fetching patient's care teams. Check the log for detail."
  end
end
