# app/controllers/observations_controller.rb
class ObservationsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count
  before_action :find_observation, only: %i[show]

  # GET /patients/:patient_id/observations
  def index
    observations = fetch_and_cache_observations(params[:patient_id])

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
    Rails.cache.fetch(cache_key_for_patient_observations(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_observations = cached_resources_type('Observation')

      if fhir_observations.blank?
        entries = fetch_observations_by_patient(patient_id)
        fhir_observations = entries.select { |entry| entry.resourceType == 'Observation' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_observations.map { |entry| Observation.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Observation:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching or parsing patient's Observations. Check the log for detail."
    end
  end

  def find_observation
    observations = fetch_and_cache_observations(params[:patient_id])
    @observation = observations.find { |response| response.id == params[:id] }
    return if @observation.present?

    resource = fetch_observation(params[:id])
    @observation = Observation.new(resource, retrieve_practitioner_roles_and_orgs)
    return if @observation.present?

    flash[:notice] = 'Observation not found'
    redirect_to patient_observations_path, id: @patient.id
  rescue StandardError => e
    Rails.logger.error("Unable to retrieve or parse Observation:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))

    flash[:danger] = 'Unable to retrieve Observation. Check logs for detail.'
    redirect_to patient_observations_path, id: @patient.id
  end
end
