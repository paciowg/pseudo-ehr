# Procedure Model
class Procedure < Resource
  attr_reader :id, :fhir_resource, :status, :status_reason, :code, :performers, :date, :procedure_display,
              :reason_codes, :asserter, :encounter, :category, :reason_references, :body_sites,
              :outcome, :complications, :notes, :date_period, :based_on, :part_of, :location,
              :follow_up, :used_reference, :used_code, :patient_id, :patient

  def initialize(fhir_procedure, bundle_entries = [])
    @id = fhir_procedure.id
    @fhir_resource = fhir_procedure
    @patient_id = @fhir_resource.subject&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @status = @fhir_resource.status
    @status_reason = retrieve_status_reason
    @code = coding_string(@fhir_resource.code&.coding).presence || '--'
    @category = retrieve_category

    # Handle dates
    @date = parse_date(@fhir_resource.performedDateTime)
    @date_period = format_period(@fhir_resource.performedPeriod)

    # Handle references to other resources
    @encounter = retrieve_encounter(bundle_entries)
    @location = retrieve_location(bundle_entries)
    @based_on = retrieve_based_on(bundle_entries)
    @part_of = retrieve_part_of(bundle_entries)

    # Handle performers
    @performers = retrieve_performers(bundle_entries)
    @asserter = parse_provider_name(@fhir_resource.asserter, bundle_entries)

    # Handle reasons
    @reason_codes = retrieve_reason_codes
    @reason_references = retrieve_reason_references(bundle_entries)

    # Handle body sites
    @body_sites = @fhir_resource.bodySite&.map { |c| coding_string(c.coding) } || []

    # Handle outcome and complications
    @outcome = coding_string(@fhir_resource.outcome&.coding).presence || '--'
    @complications = retrieve_complications

    # Handle follow-up
    @follow_up = retrieve_follow_up

    # Handle used items
    @used_reference = retrieve_used_reference(bundle_entries)
    @used_code = retrieve_used_code

    # Handle notes
    @notes = retrieve_notes(bundle_entries)

    self.class.update(self)
  end

  def performed_display
    return @date if @date != '--'
    return @date_period if @date_period != '--'

    '--'
  end

  private

  def retrieve_status_reason
    return '--' if @fhir_resource.statusReason.blank?

    if @fhir_resource.statusReason.respond_to?(:coding)
      coding_string(@fhir_resource.statusReason.coding)
    else
      @fhir_resource.statusReason.to_s
    end
  end

  def retrieve_category
    return '--' if @fhir_resource.category.blank?

    @fhir_resource.category&.map do |cat|
      coding_string(cat.coding)
    end&.join(', ')
  end

  def format_period(period)
    return '--' if period&.start.blank?

    start_date = parse_date(period.start)
    end_date = period.end.present? ? parse_date(period.end) : 'present'

    "#{start_date} to #{end_date}"
  end

  def retrieve_encounter(bundle_entries)
    return '--' if @fhir_resource.encounter&.reference.blank?

    resource_type, resource_id = @fhir_resource.encounter.reference.split('/')
    encounter_resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

    return @fhir_resource.encounter.display || @fhir_resource.encounter.reference unless encounter_resource

    # If we have an Encounter model, we could instantiate it here
    # For now, return the display or reference
    encounter_resource.type&.first&.text || @fhir_resource.encounter.display || @fhir_resource.encounter.reference
  end

  def retrieve_location(bundle_entries)
    return '--' if @fhir_resource.location&.reference.blank?

    resource_type, resource_id = @fhir_resource.location.reference.split('/')
    location_resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

    return @fhir_resource.location.display || @fhir_resource.location.reference unless location_resource

    location_resource.name || @fhir_resource.location.display || @fhir_resource.location.reference
  end

  def retrieve_based_on(bundle_entries)
    return [] if @fhir_resource.basedOn.blank?

    @fhir_resource.basedOn.map do |reference|
      resource_type, resource_id = reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      if resource
        case resource_type
        when 'CarePlan'
          care_plan = CarePlan.new(resource, bundle_entries)
          { id: care_plan.id, display: care_plan.category, type: 'CarePlan', resource: care_plan }
        when 'ServiceRequest'
          service_request = ServiceRequest.new(resource, bundle_entries)
          { id: service_request.id, display: service_request.code, type: 'ServiceRequest', resource: service_request }
        else
          { id: resource_id, display: reference.display || resource.id, type: resource_type }
        end
      else
        { id: resource_id, display: reference.display || reference.reference, type: resource_type }
      end
    end
  end

  def retrieve_part_of(bundle_entries)
    return [] if @fhir_resource.partOf.blank?

    @fhir_resource.partOf.map do |reference|
      resource_type, resource_id = reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      if resource
        case resource_type
        when 'Procedure'
          procedure = Procedure.new(resource, bundle_entries)
          { id: procedure.id, display: procedure.code, type: 'Procedure', resource: procedure }
        when 'Observation'
          observation = Observation.new(resource, bundle_entries)
          { id: observation.id, display: observation.code, type: 'Observation', resource: observation }
        when 'MedicationAdministration'
          # If we have a MedicationAdministration model, we could instantiate it here
          { id: resource.id, display: reference.display || resource.id, type: 'MedicationAdministration' }
        else
          { id: resource_id, display: reference.display || resource.id, type: resource_type }
        end
      else
        { id: resource_id, display: reference.display || reference.reference, type: resource_type }
      end
    end
  end

  def retrieve_performers(bundle_entries)
    return [] if @fhir_resource.performer.blank?

    @fhir_resource.performer.map do |performer|
      {
        function: performer.function ? coding_string(performer.function.coding) : nil,
        actor: parse_provider_name(performer.actor, bundle_entries),
        on_behalf_of: performer.onBehalfOf ? parse_provider_name(performer.onBehalfOf, bundle_entries) : nil
      }.compact
    end
  end

  def retrieve_reason_codes
    return [] if @fhir_resource.reasonCode.blank?

    @fhir_resource.reasonCode.map do |code|
      coding_string(code.coding)
    end
  end

  def retrieve_reason_references(bundle_entries)
    return [] if @fhir_resource.reasonReference.blank?

    @fhir_resource.reasonReference.map do |reference|
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
        when 'DiagnosticReport'
          diagnostic_report = DiagnosticReport.new(resource, bundle_entries)
          { id: diagnostic_report.id, display: diagnostic_report.code, type: 'DiagnosticReport',
            resource: diagnostic_report }
        when 'DocumentReference'
          # DocumentReference requires pdf and pdf_binary_id parameters
          # Since we don't have those here, we'll just return the basic info
          { id: resource_id, display: resource.type&.coding&.first&.display || resource.id, type: 'DocumentReference' }
        else
          { id: resource_id, display: reference.display || reference.reference, type: resource_type }
        end
      else
        { id: resource_id, display: reference.display || reference.reference, type: resource_type }
      end
    end
  end

  def retrieve_complications
    return [] if @fhir_resource.complication.blank?

    if @fhir_resource.complication.first.respond_to?(:coding)
      @fhir_resource.complication.map { |c| coding_string(c.coding) }
    else
      @fhir_resource.complication
    end
  end

  def retrieve_follow_up
    return [] if @fhir_resource.followUp.blank?

    @fhir_resource.followUp.map { |f| coding_string(f.coding) }
  end

  def retrieve_used_reference(bundle_entries)
    return [] if @fhir_resource.usedReference.blank?

    @fhir_resource.usedReference.map do |reference|
      resource_type, resource_id = reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      reference.display || resource&.code&.text || reference.reference
    end
  end

  def retrieve_used_code
    return [] if @fhir_resource.usedCode.blank?

    @fhir_resource.usedCode.map { |c| coding_string(c.coding) }
  end

  def retrieve_notes(bundle_entries)
    return [] if @fhir_resource.note.blank?

    @fhir_resource.note.map do |note|
      {
        author: note.authorString || (if note.authorReference
                                        parse_provider_name(note.authorReference,
                                                            bundle_entries)
                                      end),
        time: note.time ? parse_date(note.time) : nil,
        text: note.text
      }.compact
    end
  end
end
