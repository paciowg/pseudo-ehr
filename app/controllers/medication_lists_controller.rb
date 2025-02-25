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
    Rails.cache.fetch(cache_key_for_patient_medication_lists(patient_id)) do
      entries = retrieve_current_patient_resources
      fhir_lists = cached_resources_type('List')

      if fhir_lists.blank?
        entries = fetch_lists_by_patient(patient_id)
        fhir_lists = entries.select { |entry| entry.resourceType == 'List' }
      end

      entries = (entries + retrieve_practitioner_roles_and_orgs).uniq
      med_list = fhir_lists.map { |entry| MedicationList.new(entry, entries) }
      med_list.sort_by { |list| DateTime.parse(list.date) || '' }.reverse
    rescue StandardError => e
      Rails.logger.error("Error fetching or parsing Medication List:\n #{e.message.inspect}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise "Error fetching or parsing patient's Medication List. Check the log for detail."
    end
  end
end
