# app/controllers/questionnaire_responses_controller.rb
class QuestionnaireResponsesController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/questionnaire_responses
  def index
    if params[:task_id].present?
      session[:qr_task_ids] ||= []
      session[:qr_task_ids] << params[:task_id] unless session[:qr_task_ids].include?(params[:task_id])
    end
    @task_ids = session[:qr_task_ids] || []
    @pagy, @questionnaire_responses = pagy_array(fetch_questionnaire_responses(params[:patient_id]),
                                                 items: 10)
    flash.now[:notice] = I18n.t('controllers.questionnaire_responses.no_responses') if @questionnaire_responses.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @questionnaire_responses = []
  end

  # POST /patients/:patient_id/questionnaire_responses/:id/convert_to_assessments
  def convert_to_assessments
    qr = fetch_questionnaire_response

    if qr.blank?
      flash[:danger] = I18n.t('controllers.questionnaire_responses.not_found_error')
      redirect_to patient_questionnaire_responses_path(patient_id: params[:patient_id]) and return
    end

    task = TaskStatus.create_for_task(
      'Questionnaire Response to PFE Assessments Conversion',
      params[:id] # Use the QuestionnaireResponse ID as task_id for easier tracking
    )

    ConvertQrToPfeAndSubmitJob.perform_later(
      qr.fhir_resource.to_hash,
      session[:fhir_server_url],
      task.task_id,
      params[:patient_id]
    )

    flash[:notice] = I18n.t('controllers.questionnaire_responses.conversion_initiated')
    redirect_to patient_questionnaire_responses_path(patient_id: params[:patient_id], task_id: task.task_id)
  end

  private

  def fetch_questionnaire_responses(patient_id)
    qrs = QuestionnaireResponse.filter_by_patient_id(patient_id).sort_by { |qr| qr.date }.reverse
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

    QuestionnaireResponse.filter_by_patient_id(patient_id).sort_by { |qr| qr.date }.reverse
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing QuestionnaireResponses:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))

    raise "Error fetching or parsing patient's questionnaire responses. Check the log for detail."
  end

  def fetch_questionnaire_response
    qr = QuestionnaireResponse.find(params[:id])
    return qr unless qr.nil?

    qrs = fetch_questionnaire_responses(params[:patient_id])
    qrs.find { |response| response.id == params[:id] }
  end
end
