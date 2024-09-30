# frozen_string_literal: true

# app/controllers/care_teams_controller.rb
class CareTeamsController < ApplicationController
  before_action :require_server, :retrieve_patient

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
    Rails.cache.fetch(cache_key_for_patient_care_teams(patient_id), expires_in: 1.minute) do
      response = fetch_care_teams_by_patient(patient_id)
      entries = response.resource.entry.map(&:resource)
      fhir_care_teams = entries.select { |entry| entry.resourceType == 'CareTeam' }

      fhir_care_teams.map { |entry| CareTeam.new(entry, entries) }
    rescue StandardError => e
      raise "Error fetching patient's (#{patient_id}) care teams from FHIR server. Status code: #{e.message}"
    end
  end

  def fetch_care_teams_by_patient(patient_id)
    search_param = { parameters: {
      patient: patient_id,
      _include: '*'
    } }
    response = @client.search(FHIR::CareTeam, search: search_param)
    raise response&.response&.dig(:code) if response&.resource&.entry.nil?

    response
  end
end
