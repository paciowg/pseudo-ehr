# frozen_string_literal: true

# app/controllers/observations_controller.rb
class ObservationsController < ApplicationController
  before_action :require_server, :retrieve_patient
  before_action :find_observation, only: %i[show]

  # GET /patients/:patient_id/observations
  def index
    observations = fetch_and_cache_observations(
      params[:patient_id]
    )

    @grouped_observations = Observation.group_by_category_and_domain(observations)
    @collection_observations = Observation.collections(observations)
    flash.now[:notice] = 'No observations found!' if observations.blank?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @grouped_observations = {}
    @collection_observations = []
  end

  # GET /patients/:patient_id/observations/:id
  def show; end

  private

  def fetch_and_cache_observations(patient_id)
    Rails.cache.fetch(cache_key_for_patient_observations(patient_id), expires_in: 1.minute) do
      response1 = fetch_observations_by_patient(patient_id)
      entries1 = response1.resource.entry.map(&:resource)
      response2 = fetch_observations_by_patient(patient_id, 'survey')
      entries2 = response2.resource.entry.map(&:resource)
      entries = entries2 + entries1
      fhir_observations = entries.select { |entry| entry.resourceType == 'Observation' }

      fhir_observations.map { |entry| Observation.new(entry, entries) }
    rescue StandardError => e
      raise "
            Error fetching patient's (#{patient_id}) observations from FHIR server. Status code: #{e.message}
      "
    end
  end

  def fetch_observations_by_patient(patient_id, category = nil)
    search_param = if category
                     { parameters: {
                       patient: patient_id,
                       _include: '*',
                       category:
                     } }
                   else
                     { parameters: {
                       patient: patient_id,
                       _include: '*'
                     } }
                   end

    response = @client.search(FHIR::Observation, search: search_param)
    raise response&.response&.dig(:code) if response&.resource&.entry.nil?

    response
  end

  def find_observation
    observations = fetch_and_cache_observations(params[:patient_id])
    @observation = observations.find { |response| response.id == params[:id] }
    return if @observation.present?

    resource = @client.read(FHIR::Observation, params[:id])&.resource
    @observation = Observation.new(resource, [])
    return if @observation.present?

    flash[:notice] = 'Observation not found'
    redirect_to patient_observations_page_path, id: @patient.id
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patient_observations_page_path, id: @patient.id
  end

  def cache_key_for_patient_observations(patient_id)
    "patient_#{patient_id}_observations_#{session_id}"
  end
end
