# Encounter Model
class Encounter < Resource
  attr_reader :id, :fhir_resource, :status, :class_code, :type, :service_type, :priority,
              :subject, :participant, :period, :length, :reason_code, :reason_reference,
              :diagnosis, :location, :service_provider, :part_of, :patient_id, :patient

  def initialize(fhir_encounter, bundle_entries = [])
    @id = fhir_encounter.id
    @fhir_resource = fhir_encounter
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = fhir_encounter.status
    @class_code = fhir_encounter.class&.code
    @type = fhir_encounter.type&.map { |t| coding_string(t.coding) }&.join(', ')
    @service_type = coding_string(fhir_encounter.serviceType&.coding)
    @priority = coding_string(fhir_encounter.priority&.coding)
    @subject = @patient
    @participant = get_participants(fhir_encounter.participant, bundle_entries)
    @period = format_period(fhir_encounter.period)
    @length = format_duration(fhir_encounter.length)
    @reason_code = fhir_encounter.reasonCode&.map { |rc| coding_string(rc.coding) }
    @reason_reference = get_reason_references(fhir_encounter.reasonReference, bundle_entries)
    @diagnosis = get_diagnoses(fhir_encounter.diagnosis, bundle_entries)
    @location = get_locations(fhir_encounter.location, bundle_entries)
    @service_provider = parse_provider_name(fhir_encounter.serviceProvider, bundle_entries)
    @part_of = parse_provider_name(fhir_encounter.partOf, bundle_entries)

    self.class.update(self)
  end

  def start_date
    return '--' unless @period

    @period.split(' to ').first
  end

  def end_date
    return '--' unless @period

    @period.split(' to ').last
  end

  private

  def format_period(period)
    return '--' unless period&.start.present?

    start_date = parse_date(period.start)
    end_date = period.end.present? ? parse_date(period.end) : 'present'

    "#{start_date} to #{end_date}"
  end

  def format_duration(duration)
    return '--' unless duration.present?

    value = duration.value
    unit = duration.unit || duration.code

    "#{value} #{unit}"
  end

  def get_participants(participants, bundle_entries)
    return [] unless participants.present?

    participants.map do |participant|
      {
        type: participant.type&.map { |t| coding_string(t.coding) }&.join(', '),
        period: format_period(participant.period),
        individual: parse_provider_name(participant.individual, bundle_entries)
      }
    end
  end

  def get_reason_references(reason_references, bundle_entries)
    return [] unless reason_references.present?

    reason_references.map do |reference|
      resource_type, resource_id = reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      if resource
        case resource_type
        when 'Condition'
          condition = Condition.new(resource, bundle_entries)
          { id: condition.id, display: condition.code, type: 'Condition', resource: condition }
        when 'Observation'
          observation = Observation.new(resource, bundle_entries)
          { id: observation.id, display: observation.code, type: 'Observation', resource: observation }
        when 'Procedure'
          procedure = Procedure.new(resource, bundle_entries)
          { id: procedure.id, display: procedure.code, type: 'Procedure', resource: procedure }
        else
          { id: resource_id, display: reference.display || resource.id, type: resource_type }
        end
      else
        { id: resource_id, display: reference.display || reference.reference, type: resource_type }
      end
    end
  end

  def get_diagnoses(diagnoses, bundle_entries)
    return [] unless diagnoses.present?

    diagnoses.map do |diagnosis|
      condition_reference = diagnosis.condition
      resource_type, resource_id = condition_reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      if resource && resource_type == 'Condition'
        condition = Condition.new(resource, bundle_entries)
        {
          condition: { id: condition.id, display: condition.code, type: 'Condition', resource: condition },
          use: coding_string(diagnosis.use&.coding),
          rank: diagnosis.rank
        }
      else
        {
          condition: { id: resource_id, display: condition_reference.display || condition_reference.reference,
                       type: resource_type },
          use: coding_string(diagnosis.use&.coding),
          rank: diagnosis.rank
        }
      end
    end
  end

  def get_locations(locations, bundle_entries)
    return [] unless locations.present?

    locations.map do |location|
      location_reference = location.location
      resource_type, resource_id = location_reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      {
        location: resource ? resource.name : (location_reference.display || location_reference.reference),
        status: location.status,
        period: format_period(location.period)
      }
    end
  end
end
