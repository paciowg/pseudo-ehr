# app/controllers/diagnostic_report_controller.rb
class DiagnosticReportsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/diagnostic_report
  def index
    @pagy, @diagnostic_reports = pagy_array(fetch_patient_diagnostic_reports(params[:patient_id]), items: 10)
    flash.now[:notice] = 'No Diagnostic Report found' if @diagnostic_reports.empty?
  rescue StandardError => e
    Rails.logger.error e
    flash.now[:danger] = e.message
    @diagnostic_reports = []
  end

  private

  def fetch_patient_diagnostic_reports(patient_id)
    reports = DiagnosticReport.filter_by_patient_id(patient_id)
    return sort_reports(reports) unless DiagnosticReport.expired? || reports.blank?

    entries = retrieve_current_patient_resources
    fhir_diagnostic_reports = cached_resources_type('DiagnosticReport')

    if fhir_diagnostic_reports.blank?
      Rails.logger.info('Diagnostic Reports not found in patient record cache, fetching directly')
      entries = fetch_diagnostic_reports_by_patient(patient_id, 500, DiagnosticReport.updated_at)
      fhir_diagnostic_reports = entries.select { |entry| entry.resourceType == 'DiagnosticReport' }
    end

    # Get practitioner roles for reference resolution
    practitioner_roles = retrieve_practitioner_roles

    # Combine entries and create DiagnosticReport objects
    entries = (entries + practitioner_roles).uniq
    fhir_diagnostic_reports.each { |entry| DiagnosticReport.new(entry, entries) }

    reports = DiagnosticReport.filter_by_patient_id(patient_id)
    sort_reports(reports)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Diagnostic Reports:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Error fetching or parsing patient's Diagnostic Report. Check the log for detail."
  end

  def sort_reports(reports)
    reports.sort_by(&:raw_date).reverse
  end
end
