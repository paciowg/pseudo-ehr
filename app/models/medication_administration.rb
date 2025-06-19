# MedicationAdministration Model
class MedicationAdministration < Resource
  attr_reader :id, :fhir_resource, :status, :status_reason, :category, :medication, :subject,
              :context, :effective_period, :effective_date_time, :performer, :reason_code,
              :reason_reference, :request, :device, :dosage, :event_history, :note,
              :patient, :patient_id

  def initialize(fhir_medication_administration, bundle_entries = [])
    @id = fhir_medication_administration.id
    @fhir_resource = fhir_medication_administration
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = fhir_medication_administration.status
    @status_reason = fhir_medication_administration.statusReason&.map { |sr| coding_string(sr.coding) }&.join(', ')
    @category = coding_string(fhir_medication_administration.category&.coding)
    @medication = get_medication(fhir_medication_administration.medicationCodeableConcept,
                                 fhir_medication_administration.medicationReference,
                                 bundle_entries)
    @subject = @patient.name
    @context = parse_provider_name(fhir_medication_administration.try(:context), bundle_entries)
    @effective_period = format_period(fhir_medication_administration.effectivePeriod)
    @effective_date_time = parse_date(fhir_medication_administration.effectiveDateTime)
    @performer = get_performers(fhir_medication_administration.performer, bundle_entries)
    @reason_code = fhir_medication_administration.reasonCode&.map { |rc| coding_string(rc.coding) }
    @reason_reference = get_reason_references(fhir_medication_administration.reasonReference, bundle_entries)
    @request = get_med_request(bundle_entries)
    @device = get_devices(fhir_medication_administration.device, bundle_entries)
    @dosage = get_dosage(fhir_medication_administration.dosage)
    @event_history = get_event_history(fhir_medication_administration.eventHistory, bundle_entries)
    @note = get_notes(fhir_medication_administration.note)

    self.class.update(self)
  end

  def effective_time
    return @effective_date_time if @effective_date_time.present? && @effective_date_time != '--'
    return @effective_period if @effective_period.present? && @effective_period != '--'

    '--'
  end

  private

  def get_med_request(bundle_entries)
    req_id = @fhir_resource.request&.reference&.split('/')&.last
    req = MedicationRequest.find(req_id)
    return req if req

    fhir_req = get_object_from_bundle(@fhir_resource.request, bundle_entries)

    MedicationRequest.new(fhir_req, bundle_entries) if fhir_req
  end

  def get_medication(medication_codeable_concept, medication_reference, bundle_entries)
    if medication_codeable_concept.present?
      coding_string(medication_codeable_concept.coding)
    elsif medication_reference.present?
      resource_type, resource_id = medication_reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      if resource && resource_type == 'Medication'
        coding_string(resource.code&.coding)
      else
        medication_reference.display || medication_reference.reference
      end
    else
      '--'
    end
  end

  def format_period(period)
    return '--' unless period&.start.present?

    start_date = parse_date(period.start)
    end_date = period.end.present? ? parse_date(period.end) : 'present'

    "#{start_date} to #{end_date}"
  end

  def get_performers(performers, bundle_entries)
    return [] unless performers.present?

    performers.map do |performer|
      {
        function: coding_string(performer.function&.coding),
        actor: parse_provider_name(performer.actor, bundle_entries)
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
        else
          { id: resource_id, display: reference.display || resource.id, type: resource_type }
        end
      else
        { id: resource_id, display: reference.display || reference.reference, type: resource_type }
      end
    end
  end

  def get_devices(devices, bundle_entries)
    return [] unless devices.present?

    devices.map do |reference|
      resource_type, resource_id = reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      if resource && resource_type == 'Device'
        device = Device.new(resource, bundle_entries)
        { id: device.id, display: device.type, type: 'Device', resource: device }
      else
        { id: resource_id, display: reference.display || reference.reference, type: resource_type }
      end
    end
  end

  def get_dosage(dosage)
    return nil unless dosage.present?

    {
      text: dosage.text,
      site: coding_string(dosage.site&.coding),
      route: coding_string(dosage.route&.coding),
      method: coding_string(dosage.method&.coding),
      dose: format_quantity(dosage.dose),
      rate: format_rate(dosage.rateQuantity, dosage.rateRatio)
    }
  end

  def format_quantity(quantity)
    return nil unless quantity.present?

    value = quantity.value
    unit = quantity.unit || quantity.code

    "#{value} #{unit}"
  end

  def format_rate(rate_quantity, rate_ratio)
    if rate_quantity.present?
      format_quantity(rate_quantity)
    elsif rate_ratio.present?
      numerator = format_quantity(rate_ratio.numerator)
      denominator = format_quantity(rate_ratio.denominator)
      "#{numerator} / #{denominator}"
    else
      nil
    end
  end

  def get_event_history(event_history, bundle_entries)
    return [] unless event_history.present?

    event_history.map do |reference|
      resource_type, resource_id = reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      if resource && resource_type == 'Provenance'
        # If we had a Provenance model, we could instantiate it here
        { id: resource_id, display: reference.display || "Provenance #{resource_id}", type: 'Provenance' }
      else
        { id: resource_id, display: reference.display || reference.reference, type: resource_type }
      end
    end
  end

  def get_notes(notes)
    return [] unless notes.present?

    notes.map do |note|
      {
        author: note.authorString,
        time: parse_date(note.time),
        text: note.text
      }
    end
  end
end
