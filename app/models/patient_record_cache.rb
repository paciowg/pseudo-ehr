# app/models/patient_record_cache.rb
class PatientRecordCache
  # Expiration time for cached records
  EXPIRATION_TIME = 1.hour

  class << self
    def patient_records
      @patient_records ||= {}
    end

    def patient_records_last_sync
      @patient_records_last_sync ||= {}
    end

    def grouped_patient_records
      @grouped_patient_records ||= {}
    end

    # Get a patient record from the cache
    def get_patient_record(patient_id)
      return unless patient_record_exists?(patient_id)

      patient_records[patient_id]
    end

    # Store a patient record in the cache
    def store_patient_record(patient_id, patient_record)
      patient_records[patient_id] = patient_record
      patient_records_last_sync[patient_id] = Time.zone.now

      Rails.logger.info("Stored patient record in memory for patient #{patient_id} " \
                        "(#{patient_record.size} resources)")

      grouped_data = patient_record&.group_by(&:resourceType) || {}
      store_grouped_patient_record(patient_id, grouped_data)
    end

    # Clear a patient record from the cache
    def clear_patient_record(patient_id)
      patient_records.delete(patient_id)
      patient_records_last_sync.delete(patient_id)
      Rails.logger.info("Cleared in-memory patient record for patient #{patient_id}")

      clear_grouped_patient_record(patient_id)
    end

    def clear_data
      @patient_records = {}
      @patient_records_last_sync = {}
      @grouped_patient_records = {}
    end

    # Get the last sync time for a patient record
    def get_last_sync_time(patient_id)
      patient_records_last_sync[patient_id]
    end

    # Update a patient record with new resources
    def update_patient_record(patient_id, new_resources)
      return unless patient_records[patient_id]

      existing_resources = patient_records[patient_id]

      existing_map = {}
      existing_resources.each do |resource|
        key = "#{resource.resourceType}/#{resource.id}"
        existing_map[key] = resource
      end

      # Process new resources - either add or replace existing ones
      new_resources.each do |resource|
        key = "#{resource.resourceType}/#{resource.id}"
        existing_map[key] = resource
      end

      updated_resources = existing_map.values
      store_patient_record(patient_id, updated_resources)
    end

    # Add a single resource to a patient record
    def add_resource_to_patient_record(patient_id, resource)
      records = get_patient_record(patient_id)
      records ||= []
      records << resource
      store_patient_record(patient_id, records)
    end

    # Get a grouped patient record from the cache
    def get_grouped_patient_record(patient_id)
      grouped_patient_records[patient_id]
    end

    # Store a grouped patient record in the cache
    def store_grouped_patient_record(patient_id, grouped_data)
      grouped_patient_records[patient_id] = grouped_data

      Rails.logger.info("Stored grouped patient record in memory for patient #{patient_id}")
    end

    # Clear a grouped patient record from the cache
    def clear_grouped_patient_record(patient_id)
      grouped_patient_records.delete(patient_id)
      Rails.logger.info("Cleared in-memory grouped patient record for patient #{patient_id}")
    end

    # Check if a patient record exists in the cache
    def patient_record_exists?(patient_id)
      patient_records.key?(patient_id) &&
        patient_records_last_sync.key?(patient_id) &&
        patient_records_last_sync[patient_id] > EXPIRATION_TIME.ago
    end

    # Observations by questionnaire response id
    def observations_by_questionnaire_response_id(qr_id)
      return [] if qr_id.blank?

      all_observations = patient_records.values.flat_map do |records|
        records.select { |r| r.resourceType == 'Observation' }
      end

      all_observations.select do |obs|
        obs.try(:derivedFrom)&.any? do |ref|
          ref.is_a?(FHIR::Reference) && ref.reference == "QuestionnaireResponse/#{qr_id}"
        end
      end
    end
  end
end
