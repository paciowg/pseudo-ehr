# app/controllers/observations_controller.rb
class ObservationsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count
  before_action :find_observation, only: %i[show]

  # GET /patients/:patient_id/observations
  def index
    observations = fetch_observations(params[:patient_id])

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

  def fetch_observations(patient_id)
    obs = Observation.filter_by_patient_id(patient_id)
    return obs unless Observation.expired? || obs.blank?

    entries = retrieve_current_patient_resources
    fhir_observations = cached_resources_type('Observation')

    if fhir_observations.blank?
      Rails.logger.info('Observations not found in patient record cache, fetching directly')
      entries = fetch_observations_by_patient(patient_id, 500, Observation.updated_at)
      fhir_observations = entries.select { |entry| entry.resourceType == 'Observation' }
    end

    entries = (entries + retrieve_practitioner_roles).uniq
    fhir_observations.each { |entry| Observation.new(entry, entries) }

    Observation.filter_by_patient_id(patient_id)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Observation:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Error fetching or parsing patient's Observations. Check the log for detail."
  end

  def find_observation
    @observation = Observation.find(params[:id])
    return if @observation.present?

    cached_observation = find_cached_resource('Observation', params[:id])
    entries = (retrieve_current_patient_resources + retrieve_practitioner_roles).uniq
    if cached_observation.present?
      @observation = Observation.new(cached_observation, entries)
      return
    end

    # If still not found, fetch it directly from the server
    Rails.logger.info("Observation #{params[:id]} not found in cache, fetching directly")
    resource = fetch_observation(params[:id])
    @observation = Observation.new(resource, entries)
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
