# app/controllers/questionnaire_responses_controller.rb
class QuestionnaireResponsesController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/questionnaire_responses
  def index
    @pagy, @questionnaire_responses = pagy_array(fetch_questionnaire_responses(params[:patient_id]),
                                                 items: 10)
    flash.now[:notice] = I18n.t('controllers.questionnaire_responses.no_responses') if @questionnaire_responses.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @questionnaire_responses = []
  end

  private

  def fetch_questionnaire_responses(patient_id)
    qrs = QuestionnaireResponse.filter_by_patient_id(patient_id)
    return qrs unless QuestionnaireResponse.expired? || qrs.blank?

    entries = retrieve_current_patient_resources
    fhir_questionnaire_responses = cached_resources_type('QuestionnaireResponse')

    if fhir_questionnaire_responses.blank?
      Rails.logger.info('Questionnaire responses not found in patient record cache, fetching directly')
      entries = fetch_questionnaire_responses_by_patient(patient_id, 500, QuestionnaireResponse.updated_at)
      fhir_questionnaire_responses = entries.select { |entry| entry.resourceType == 'QuestionnaireResponse' }
    end

    entries = (entries + retrieve_practitioner_roles).uniq
    fhir_questionnaire_responses.each { |entry| QuestionnaireResponse.new(entry, entries) }

    QuestionnaireResponse.filter_by_patient_id(patient_id)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing QuestionnaireResponses:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))

    raise "Error fetching or parsing patient's questionnaire responses. Check the log for detail."
  end
end
