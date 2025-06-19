# Immunization Model
class Immunization < Resource
  attr_reader :id, :fhir_resource, :status, :status_reason, :vaccine_code, :patient,
              :encounter, :occurrence_date, :primary_source, :report_origin, :location,
              :manufacturer, :lot_number, :expiration_date, :site, :route, :dose_quantity,
              :performer, :note, :reason_code, :reason_reference, :is_subpotent,
              :subpotent_reason, :education, :protocol_applied, :patient_id

  def initialize(fhir_immunization, bundle_entries = [])
    @id = fhir_immunization.id
    @fhir_resource = fhir_immunization
    @patient_id = @fhir_resource.patient&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = fhir_immunization.status
    @status_reason = coding_string(fhir_immunization.statusReason&.coding)
    @vaccine_code = coding_string(fhir_immunization.vaccineCode&.coding)
    @encounter = get_encounter(bundle_entries)
    @occurrence_date = parse_date(fhir_immunization.occurrenceDateTime)
    @primary_source = fhir_immunization.primarySource
    @report_origin = coding_string(fhir_immunization.reportOrigin&.coding)
    @location = parse_provider_name(fhir_immunization.location, bundle_entries)
    @manufacturer = parse_provider_name(fhir_immunization.manufacturer, bundle_entries)
    @lot_number = fhir_immunization.lotNumber
    @expiration_date = parse_date(fhir_immunization.expirationDate)
    @site = coding_string(fhir_immunization.site&.coding)
    @route = coding_string(fhir_immunization.route&.coding)
    @dose_quantity = format_quantity(fhir_immunization.doseQuantity)
    @performer = get_performers(fhir_immunization.performer, bundle_entries)
    @note = get_notes(fhir_immunization.note)
    @reason_code = fhir_immunization.reasonCode&.map { |rc| coding_string(rc.coding) }
    @reason_reference = get_reason_references(fhir_immunization.reasonReference, bundle_entries)
    @is_subpotent = fhir_immunization.isSubpotent
    @subpotent_reason = fhir_immunization.subpotentReason&.map { |sr| coding_string(sr.coding) }
    @education = get_education(fhir_immunization.education)
    @protocol_applied = get_protocol_applied(fhir_immunization.protocolApplied)

    self.class.update(self)
  end

  private

  def get_encounter(bundle_entries)
    encounter_id = @fhir_resource.encounter&.reference&.split('/')&.last
    encounter = Encounter.find(encounter_id)
    return encounter if encounter

    fhir_encounter = get_object_from_bundle(@fhir_resource.encounter, bundle_entries)
    Encounter.new(fhir_encounter, bundle_entries) if fhir_encounter
  end

  def format_quantity(quantity)
    return '--' if quantity.blank?

    value = quantity.value
    unit = quantity.unit || quantity.code

    "#{value} #{unit}"
  end

  def get_performers(performers, bundle_entries)
    return [] if performers.blank?

    performers.map do |performer|
      {
        function: coding_string(performer.function&.coding),
        actor: parse_provider_name(performer.actor, bundle_entries)
      }
    end
  end

  def get_notes(notes)
    return [] if notes.blank?

    notes.map do |note|
      {
        author: note.authorString,
        time: parse_date(note.time),
        text: note.text
      }
    end
  end

  def get_reason_references(reason_references, bundle_entries)
    return [] if reason_references.blank?

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

  def get_education(education)
    return [] if education.blank?

    education.map do |edu|
      {
        document_type: edu.documentType,
        reference: edu.reference,
        publication_date: parse_date(edu.publicationDate),
        presentation_date: parse_date(edu.presentationDate)
      }
    end
  end

  def get_protocol_applied(protocol_applied)
    return [] if protocol_applied.blank?

    protocol_applied.map do |protocol|
      {
        series: protocol.series,
        authority: parse_provider_name(protocol.authority, []),
        target_disease: protocol.targetDisease&.map { |td| coding_string(td.coding) },
        dose_number_string: protocol.doseNumberString,
        dose_number_positive_int: protocol.doseNumberPositiveInt,
        series_doses_string: protocol.seriesDosesString,
        series_doses_positive_int: protocol.seriesDosesPositiveInt
      }
    end
  end
end
