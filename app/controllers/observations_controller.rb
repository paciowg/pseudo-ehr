# app/controllers/observations_controller.rb
class ObservationsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count
  before_action :find_observation, only: %i[show]

  # GET /patients/:patient_id/observations
  def index
    observations = fetch_observations(params[:patient_id])
    if params[:derived_from].present?
      observations = observations.select do |obs|
        obs.derived_from.map { |r| r[:reference] }.include?(params[:derived_from])
      end
    end

    @grouped_observations = Observation.group_by_category_and_domain(observations)
    @collection_observations = Observation.collections(observations)
    flash.now[:notice] = I18n.t('controllers.observations.no_observations') if observations.blank?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @grouped_observations = {}
    @collection_observations = []
  end

  # GET /patients/:patient_id/observations/:id
  def show; end

  # GET /patients/:patient_id/observations/graph
  def graph
    ids = params[:ids]&.split(',')
    if ids.blank?
      return render json: { error: 'No observation IDs provided' }, status: :bad_request
    end

    observations = ids.map { |id| Observation.find(id) }.compact
    if observations.blank?
      return render json: { error: 'No matching observations found' }, status: :not_found
    end

    first_obs = observations.first
    is_component_obs = first_obs.collection?

    if is_component_obs
      # Handle component observations (e.g., Blood Pressure panels)
      title = first_obs.code
      series = {}
      y_axis_label = ''

      observations.each do |obs|
        next unless obs.collection?

        obs.members.each do |member|
          series[member.code] ||= { name: member.code, data: [] }
          value, unit = parse_measurement(member)
          y_axis_label = unit if y_axis_label.blank? && unit.present? # Use first unit found
          series[member.code][:data] << { x: obs.effective_date_time, y: value } if value
        end
      end

      # Sort data points by date for each series
      series.values.each do |s|
        s[:data].sort_by! { |d| d[:x] }
      end

      render json: {
        title: title,
        y_axis_label: y_axis_label,
        series: series.values
      }
    else
      # Handle single-value observations
      title = first_obs.code
      _value, unit = parse_measurement(first_obs)
      y_axis_label = unit

      series_data = observations.map do |obs|
        value, _unit = parse_measurement(obs)
        { x: obs.effective_date_time, y: value } if value
      end.compact.sort_by { |d| d[:x] }

      render json: {
        title: title,
        y_axis_label: y_axis_label,
        series: [{
          name: title,
          data: series_data
        }]
      }
    end
  rescue StandardError => e
    Rails.logger.error("Error generating graph data: #{e.message}")
    render json: { error: 'An unexpected error occurred' }, status: :internal_server_error
  end

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

    flash[:notice] = I18n.t('controllers.observations.observation_not_found')
    redirect_to patient_observations_path, id: @patient.id
  rescue StandardError => e
    Rails.logger.error("Unable to retrieve or parse Observation:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))

    flash[:danger] = I18n.t('controllers.observations.retrieve_error')
    redirect_to patient_observations_path, id: @patient.id
  end

  def parse_measurement(observation)
    quantity = observation.fhir_resource.valueQuantity
    return [nil, nil] unless quantity

    value = quantity.value
    unit = quantity.unit.presence || quantity.code.presence
    [value, unit]
  end
end
