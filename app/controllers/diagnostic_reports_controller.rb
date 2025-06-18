# app/controllers/diagnostic_report_controller.rb
class DiagnosticReportsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/diagnostic_report
  def index
    @diagnostic_reports = fetch_patient_diagnostic_reports(params[:patient_id])
    flash.now[:notice] = 'No Diagnostic Report found' if @diagnostic_reports.empty?
  rescue StandardError => e
    Rails.logger.error e
    flash.now[:danger] = e.message
    @diagnostic_reports = []
  end

  private

  def fetch_patient_diagnostic_reports(patient_id)
    Rails.cache.fetch(cache_key_for_patient_diagnostic_reports(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_diagnostic_reports = cached_resources_type('DiagnosticReport')

      if fhir_diagnostic_reports.blank?
        entries = fetch_diagnostic_reports_by_patient(patient_id)
        fhir_diagnostic_reports = entries.select { |entry| entry.resourceType == 'DiagnosticReport' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      fhir_diagnostic_reports.map { |entry| DiagnosticReport.new(entry, entries) }
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Diagnostic Reports:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching or parsing patient's Diagnostic Report. Check the log for detail."
    end
  end
end
