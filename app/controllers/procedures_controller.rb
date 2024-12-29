# app/controllers/procedures_controller.rb
class ProceduresController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/procedures
  def index
    @procedures = fetch_patient_procedures(params[:patient_id])
    flash.now[:notice] = 'No Procedure found' if @procedures.empty?
  rescue StandardError => e
    Rails.logger.error e
    flash.now[:danger] = e.message
    @procedures = []
  end

  private

  def fetch_patient_procedures(patient_id)
    Rails.cache.fetch(cache_key_for_patient_procedures(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_procedures = cached_resources_type('Procedures')

      if fhir_procedures.blank?
        entries = fetch_procedures_by_patient(patient_id)
        fhir_procedures = entries.select { |entry| entry.resourceType == 'Procedure' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_procedures.map { |entry| Procedure.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Procedure:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching or parsing patient's Procedure. Check the log for detail."
    end
  end
end
