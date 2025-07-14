# ImmunizationRecommendation Model
class ImmunizationRecommendation < Resource
  attr_reader :id, :fhir_resource, :date, :authority, :identifier, :recommendation,
              :patient, :patient_id

  def initialize(fhir_immunization_recommendation, bundle_entries = [])
    @id = fhir_immunization_recommendation.id
    @fhir_resource = fhir_immunization_recommendation
    @patient_id = @fhir_resource.patient&.reference&.split('/')&.last
    @patient = Patient.find(@patient_id)
    @date = parse_date(fhir_immunization_recommendation.date)
    @authority = parse_provider_name(fhir_immunization_recommendation.authority, bundle_entries)
    @identifier = if fhir_immunization_recommendation.identifier.respond_to?(:map)
                    fhir_immunization_recommendation.identifier&.map do |id|
                      "#{id.system}: #{id.value}"
                    end&.join(', ')
                  else
                    '--'
                  end
    @recommendation = get_recommendations(fhir_immunization_recommendation.recommendation, bundle_entries)

    self.class.update(self)
  end

  private

  def get_recommendations(recommendations, bundle_entries)
    return [] if recommendations.blank?

    recommendations.map do |rec|
      {
        vaccine_code: rec.vaccineCode&.map { |vc| coding_string(vc.coding) },
        target_disease: coding_string(rec.targetDisease&.coding),
        contraindicating_vaccine_code: rec.contraindication&.map { |c| coding_string(c.coding) },
        forecast_status: coding_string(rec.forecastStatus&.coding),
        forecast_reason: rec.forecastReason&.map { |fr| coding_string(fr.coding) },
        date_criterion: get_date_criterion(rec.dateCriterion),
        description: rec.description,
        series: rec.series,
        dose_number_string: rec.doseNumberString,
        dose_number_positive_int: rec.doseNumberPositiveInt,
        series_doses_string: rec.seriesDosesString,
        series_doses_positive_int: rec.seriesDosesPositiveInt,
        supporting_immunization: get_supporting_immunizations(rec.supportingImmunization, bundle_entries),
        supporting_patient_information: get_supporting_patient_info(rec.supportingPatientInformation, bundle_entries)
      }
    end
  end

  def get_date_criterion(date_criterion)
    return [] if date_criterion.blank?

    date_criterion.map do |dc|
      {
        code: coding_string(dc.code&.coding),
        value: parse_date(dc.value)
      }
    end
  end

  def get_supporting_immunizations(supporting_immunizations, bundle_entries)
    return [] if supporting_immunizations.blank?

    supporting_immunizations.map do |reference|
      resource_type, resource_id = reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      if resource && resource_type == 'Immunization'
        immunization = Immunization.new(resource, bundle_entries)
        { id: immunization.id, display: immunization.vaccine_code, type: 'Immunization', resource: immunization }
      else
        { id: resource_id, display: reference.display || reference.reference, type: resource_type }
      end
    end
  end

  def get_supporting_patient_info(supporting_patient_info, bundle_entries)
    return [] if supporting_patient_info.blank?

    supporting_patient_info.map do |reference|
      resource_type, resource_id = reference.reference.split('/')
      resource = bundle_entries.find { |res| res.resourceType == resource_type && res.id == resource_id }

      if resource
        case resource_type
        when 'Observation'
          observation = Observation.new(resource, bundle_entries)
          { id: observation.id, display: observation.code, type: 'Observation', resource: observation }
        when 'AllergyIntolerance'
          allergy = AllergyIntolerance.new(resource, bundle_entries)
          { id: allergy.id, display: allergy.code, type: 'AllergyIntolerance', resource: allergy }
        else
          { id: resource_id, display: reference.display || resource.id, type: resource_type }
        end
      else
        { id: resource_id, display: reference.display || reference.reference, type: resource_type }
      end
    end
  end
end
