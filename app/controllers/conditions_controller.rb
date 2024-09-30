# frozen_string_literal: true

# app/controllers/conditions_controller.rb
class ConditionsController < ApplicationController
  before_action :require_server, :retrieve_patient
  before_action :find_condition, only: %i[show]

  # GET /patients/:patient_id/conditions
  def index
    @pagy, @conditions = pagy_array(fetch_and_cache_conditions(params[:patient_id]),
                                    items: 10)
    flash.now[:notice] = 'Patient has no conditions' if @conditions.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @conditions = []
  end

  # GET /patients/:patient_id/conditions/:id
  def show; end

  private

  def fetch_and_cache_conditions(patient_id)
    Rails.cache.fetch(cache_key_for_patient_conditions(patient_id), expires_in: 1.minute) do
      response = fetch_conditions_by_patient(patient_id)
      entries = response.resource.entry.map(&:resource)
      fhir_conditions = entries.select { |entry| entry.resourceType == 'Condition' }

      conditions = fhir_conditions.map do |entry|
        Condition.new(entry, entries)
      end
      conditions.sort_by { |cond| cond.onset_date_time || cond.recorded_date || '' }.reverse
    rescue StandardError => e
      raise "
            Error fetching patient's (#{patient_id}) conditions from FHIR server. Status code: #{e.message}
      "
    end
  end

  def fetch_conditions_by_patient(patient_id)
    search_param = { parameters: {
      patient: patient_id,
      _include: '*'
    } }
    response = @client.search(FHIR::Condition, search: search_param)
    raise response&.response&.dig(:code) if response&.resource&.entry.nil?

    response
  end

  def find_condition
    conditions = fetch_and_cache_conditions(params[:patient_id])
    @condition = conditions.find { |response| response.id == params[:id] }
    return if @condition.present?

    flash[:notice] = 'Condition not found'
    redirect_to patient_conditions_page_path, id: @patient.id
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patient_conditions_page_path, id: @patient.id
  end
end
