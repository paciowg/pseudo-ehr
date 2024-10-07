# app/controllers/questionnaire_responses_controller.rb
class QuestionnaireResponsesController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/questionnaire_responses
  def index
    @pagy, @questionnaire_responses = pagy_array(fetch_and_cache_questionnaire_responses(params[:patient_id]),
                                                 items: 10)
    flash.now[:notice] = 'Patient has not answer any questionnaire yet' if @questionnaire_responses.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @questionnaire_responses = []
  end

  private

  def fetch_and_cache_questionnaire_responses(patient_id)
    Rails.cache.fetch(cache_key_for_patient_questionnaire_responses(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_questionnaire_responses = cached_resources_type('QuestionnaireResponse')

      if fhir_questionnaire_responses.blank?
        entries = fetch_questionnaire_responses_by_patient(patient_id)
        fhir_questionnaire_responses = entries.select { |entry| entry.resourceType == 'QuestionnaireResponse' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_questionnaire_responses.map { |entry| QuestionnaireResponse.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing QuestionnaireResponses:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))

      raise "Error fetching or parsing patient's questionnaire responses. Check the log for detail."
    end
  end
end
