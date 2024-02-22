# frozen_string_literal: true

# app/controllers/questionnaire_responses_controller.rb
class QuestionnaireResponsesController < ApplicationController
  before_action :require_server, :retrieve_patient
  before_action :find_questionnaire_response, only: %i[show]

  # GET /patients/:patient_id/questionnaire_responses
  def index
    @pagy, @questionnaire_responses = pagy_array(fetch_and_cache_questionnaire_responses(params[:patient_id]),
                                                 items: 10)
    flash.now[:notice] = 'Patient has not answer any questionnaire yet' if @questionnaire_responses.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @questionnaire_responses = []
  end

  # GET /patients/:patient_id/questionnaire_responses/:id
  def show; end

  private

  def fetch_and_cache_questionnaire_responses(patient_id)
    Rails.cache.fetch(cache_key_for_patient_questionnaire_responses(patient_id), expires_in: 1.minute) do
      response = fetch_questionnaire_responses_by_patient(patient_id)
      entries = response.resource.entry.map(&:resource)
      fhir_questionnaire_responses = entries.select { |entry| entry.resourceType == 'QuestionnaireResponse' }

      fhir_questionnaire_responses.map { |entry| QuestionnaireResponse.new(entry, entries) }.sort_by(&:date).reverse
    rescue StandardError => e
      raise "
            Error fetching patient's (#{patient_id}) questionnaire responses from FHIR server. Status code: #{e.message}
      "
    end
  end

  def fetch_questionnaire_responses_by_patient(patient_id)
    search_param = { parameters: {
      patient: patient_id,
      _include: '*'
    } }
    response = @client.search(FHIR::QuestionnaireResponse, search: search_param)
    raise response&.response&.dig(:code) if response&.resource&.entry.nil?

    response
  end

  def find_questionnaire_response
    questionnaire_responses = fetch_and_cache_questionnaire_responses(params[:patient_id])
    @questionnaire_response = questionnaire_responses.find { |response| response.id == params[:id] }
    return if @questionnaire_response.present?

    flash[:notice] = 'Questionnaire response not found'
    redirect_to patient_questionnaire_responses_page_path, id: @patient.id
  rescue StandardError => e
    flash[:danger] = e.message
    redirect_to patient_questionnaire_responses_page_path, id: @patient.id
  end

  def cache_key_for_patient_questionnaire_responses(patient_id)
    "patient_#{patient_id}_questionnaire_responses_#{session_id}"
  end
end
