# frozen_string_literal: true

# app/controllers/goals_controller.rb
class GoalsController < ApplicationController
  before_action :require_server, :retrieve_patient
  before_action :find_goal, only: %i[show]

  # GET /patients/:patient_id/goals
  def index
    @pagy, @goals = pagy_array(fetch_and_cache_goals(params[:patient_id]),
                               items: 5)
    flash.now[:notice] = 'Patient has no goals' if @goals.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @goals = []
  end

  # GET /patients/:patient_id/goals/:id
  def show; end

  private

  def fetch_and_cache_goals(patient_id)
    Rails.cache.fetch(cache_key_for_patient_goals(patient_id), expires_in: 1.minute) do
      response = fetch_goals_by_patient(patient_id)
      entries = response.resource.entry.map(&:resource)
      fhir_goals = entries.select { |entry| entry.resourceType == 'Goal' }

      fhir_goals.map { |entry| Goal.new(entry, entries) }
    rescue StandardError => e
      raise "
            Error fetching patient's (#{patient_id}) goals from FHIR server. Status code: #{e.message}
      "
    end
  end

  def fetch_goals_by_patient(patient_id)
    search_param = { parameters: {
      patient: patient_id,
      _include: '*'
    } }
    response = @client.search(FHIR::Goal, search: search_param)
    raise response&.response&.dig(:code) if response&.resource&.entry.nil?

    response
  end

  def find_goal
    goals = fetch_and_cache_goals(params[:patient_id])
    @goal = goals.find { |response| response.id == params[:id] }
    return if @goal.present?

    flash[:notice] = 'Goal not found'
    redirect_to patient_goals_page_path, id: @patient.id
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patient_goals_page_path, id: @patient.id
  end
end
