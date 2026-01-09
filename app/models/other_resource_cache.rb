# Support caching of resources that we want to load all the time that may not be connected to patient records
# with existing relationships (e.g., PractitionerRole, Organization)
class OtherResourceCache
  # Expiration time for cached records
  EXPIRATION_TIME = 1.hour

  class << self

    def all
      @all ||= []
    end

    # Return a list of resources given a type or nil if there are none
    def by_type(type)
      @by_type && @by_type[type]
    end

    def lookup(type, id)
      @by_type && @by_type[type]&.detect { |r| r.id == id }
    end

    def updated_at(time = nil)
      @updated_at = time if time.present?
      @updated_at
    end

    def expired?
      return true unless updated_at

      updated_at < EXPIRATION_TIME.ago
    end

    def update_records(new_resources)
      existing_map = {}
      all.each do |resource|
        key = "#{resource.resourceType}/#{resource.id}"
        existing_map[key] = resource
      end

      # Process new resources - either add or replace existing ones
      new_resources.each do |resource|
        key = "#{resource.resourceType}/#{resource.id}"
        existing_map[key] = resource
      end

      @all = existing_map.values
      @by_type = @all.group_by { |r| r.resourceType }
      updated_at(Time.zone.now)
    end

    def clear_data
      all.clear
    end
  end
end
