# app/controllers/medication_lists_controller.rb
class MedicationListsController < ApplicationController
  before_action :require_server, :retrieve_patient, :set_resources_count

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
    med_list = MedicationList.filter_by_patient_id(patient_id)
    return sort_list(med_list) unless MedicationList.expired? || med_list.blank?

    entries = retrieve_current_patient_resources
    fhir_lists = cached_resources_type('List')

    if fhir_lists.blank?
      Rails.logger.info('Medication lists not found in patient record cache, fetching directly')
      entries = fetch_lists_by_patient(patient_id, 500, MedicationList.updated_at)
      fhir_lists = entries.select { |entry| entry.resourceType == 'List' }
    end

    practitioner_roles = retrieve_practitioner_roles
    entries = (entries + practitioner_roles).uniq

    fhir_lists.each { |entry| MedicationList.new(entry, entries) }

    med_list = MedicationList.filter_by_patient_id(patient_id)
    sort_list(med_list)
  rescue StandardError => e
    Rails.logger.error("Error fetching or parsing Medication List:\n #{e.message.inspect}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise "Error fetching or parsing patient's Medication List. Check the log for detail."
  end

  def sort_list(med_list)
    med_list.sort_by { |l| DateTime.parse(l.date) || '' }.reverse
  end
end
