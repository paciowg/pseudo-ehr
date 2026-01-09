# app/controllers/procedures_controller.rb
class ProceduresController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/procedures
  def index
    @pagy, @procedures = pagy_array(fetch_patient_procedures(params[:patient_id]), items: 10)
    flash.now[:notice] = I18n.t('controllers.procedures.no_procedures') if @procedures.empty?
  rescue StandardError => e
    Rails.logger.error e
    flash.now[:danger] = e.message
    @procedures = []
  end

  private

  def fetch_patient_procedures(patient_id)
    procedures = Procedure.filter_by_patient_id(patient_id)
    return procedures unless Procedure.expired? || procedures.blank?

    entries = retrieve_current_patient_resources
    fhir_procedures = cached_resources_type('Procedures')

    if fhir_procedures.blank?
      entries = fetch_procedures_by_patient(patient_id, 500, Procedure.updated_at)
      fhir_procedures = entries.select { |entry| entry.resourceType == 'Procedure' }
    end

    entries = (entries + retrieve_other_resources).uniq
    fhir_procedures.each { |entry| Procedure.new(entry, entries) }

    Procedure.filter_by_patient_id(patient_id)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Procedure:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Error fetching or parsing patient's Procedure. Check the log for detail."
  end
end
