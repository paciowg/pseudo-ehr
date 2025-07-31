class DetectedIssuesController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

  # GET /patients/:patient_id/detected_issues
  def index
    @detected_issues = fetch_patient_detected_issues(params[:patient_id])
    flash.now[:notice] = I18n.t('controllers.detected_issues.no_detected_issues') if @detected_issues.empty?
  rescue StandardError => e
    flash.now[:danger] = e.message
    @detected_issues = []
  end

  private

  def fetch_patient_detected_issues(patient_id)
    detected_issues = DetectedIssue.filter_by_patient_id(patient_id)
    return detected_issues unless DetectedIssue.expired? || detected_issues.blank?

    entries = retrieve_current_patient_resources
    fhir_detected_issues = cached_resources_type('DetectedIssue')

    if fhir_detected_issues.blank?
      Rails.logger.info('DetectedIssues not found in patient record cache, fetching directly')
      entries = fetch_detected_issues_by_patient(patient_id, 500, DetectedIssues.updated_at)
      fhir_detected_issues = entries.select { |entry| entry.resourceType == 'DetectedIssue' }
    end

    # Get practitioner roles for reference resolution
    practitioner_roles = retrieve_practitioner_roles

    # Combine entries and create DetectedIssue objects
    entries = (entries + practitioner_roles).uniq
    fhir_detected_issues.each { |entry| DetectedIssue.new(entry, entries) }

    DetectedIssue.filter_by_patient_id(patient_id)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing DetectedIssues:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))

    raise "Error fetching or parsing patient's detected issues. Check the log for detail."
  end
end
