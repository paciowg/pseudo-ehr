# This provide a centralized place for shared code and behavior that needs to be available across
# all your application's models that does not inherit from ApplicationRecord.
class Resource
  include ModelHelper
  include ModelValueSet

  # Expiration time for cached records
  EXPIRATION_TIME = 1.hour

  class << self
    def update(resource)
      remove(resource.id) if exist?(resource.id)

      all << resource
      all_by_id[resource.id] = resource
      updated_at(Time.zone.now)
    end

    def remove(id)
      return unless exist?(id)

      deleted_resource = all_by_id.delete(id)
      all.delete(deleted_resource)
    end

    def find(id)
      return if expired?

      all_by_id[id]
    end

    def filter_by_patient_id(patient_id)
      all.filter { |r| r.try(:patient_id).present? && r.patient_id == patient_id }
    end

    def clear_patient_data(patient_id)
      data = filter_by_patient_id(patient_id)
      data.each { |res| remove(res.id) }
    end

    def exist?(id)
      all_by_id.key?(id)
    end

    def expired?
      return true  unless updated_at

      updated_at < EXPIRATION_TIME.ago
    end

    def updated_at(time = nil)
      @updated_at = time if time.present?
      @updated_at
    end

    def all
      @all ||= []
    end

    def all_by_id
      @all_by_id ||= {}
    end

    def clear_data
      all.clear
      all_by_id.clear
    end
  end
end
