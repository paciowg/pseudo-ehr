# app/controllers/care_teams_controller.rb
class CareTeamsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/care_teams
  def index
    @care_teams = fetch_and_cache_care_teams(params[:patient_id])
    flash.now[:notice] = 'Patient has no care team yet' if @care_teams.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @care_teams = []
  end

  private

  def fetch_and_cache_care_teams(patient_id)
    Rails.cache.fetch(cache_key_for_patient_care_teams(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_care_teams = cached_resources_type('CareTeam')

      if fhir_care_teams.blank?
        entries = fetch_care_teams_by_patient(patient_id)
        fhir_care_teams = entries.select { |entry| entry.resourceType == 'CareTeam' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_care_teams.map { |entry| CareTeam.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Care team:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching patient's care teams. Check the log for detail."
    end
  end
end
