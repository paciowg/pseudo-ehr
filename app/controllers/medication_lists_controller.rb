# frozen_string_literal: true

# app/controllers/medication_lists_controller.rb
class MedicationListsController < ApplicationController
  before_action :require_server, :retrieve_patient

  # GET /patients/:patient_id/medication_lists
  def index
    @medication_lists = fetch_patient_medication_lists(params[:patient_id])
    flash.now[:notice] = 'No Medication list found' if @medication_lists.empty?
  rescue StandardError => e
    Rails.logger.error e
    flash.now[:danger] = e.message
    @medication_lists = []
  end

  private

  def fetch_patient_medication_lists(patient_id)
    Rails.cache.fetch(cache_key_for_patient_medication_lists(patient_id), expires_in: 5.minutes) do
      response = @client.search(FHIR::List, search: medication_lists_search_param)
      raise response&.response&.dig(:code) if response&.resource&.entry.nil?

      request = response.request
      add_query("#{request[:method].upcase} #{request[:url]}")

      entries = response.resource.entry.map(&:resource)

      fhir_lists = entries.select { |entry| entry.resourceType == 'List' }

      fhir_lists.map { |list| MedicationList.new(list, entries) }
    rescue StandardError => e
      raise "Error fetching patient's (#{patient_id}) medication list: #{e.message}"
    end
  end

  def cache_key_for_patient_medication_lists(patient_id)
    "patient_#{patient_id}_medication_lists_#{session_id}"
  end

  def medication_lists_search_param
    {
      parameters: {
        patient: params[:patient_id],
        _include: '*'
      }
    }
  end
end
