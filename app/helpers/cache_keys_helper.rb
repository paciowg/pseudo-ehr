module CacheKeysHelper
  def session_id
    session[:id] ||= Base64.encode64(SecureRandom.random_number(2**64).to_s).chomp
  end

  # Cache key for search results - still session-specific as it depends on search parameters
  def cache_key_for_patients
    "patients_#{session_id}"
  end

  # Resource-specific cache keys - not tied to session for better sharing
  def cache_key_for_patient(patient_id)
    "fhir_patient_#{patient_id}"
  end

  def cache_key_for_patient_record(patient_id)
    "patient_#{patient_id}_all_resources"
  end

  def cache_key_for_patient_adis(patient_id)
    "patient_#{patient_id}_adis"
  end

  def cache_key_for_adi(adi_id)
    "adi_#{adi_id}"
  end

  def cache_key_for_patient_care_teams(patient_id)
    "patient_#{patient_id}_care_teams"
  end

  def cache_key_for_patient_conditions(patient_id)
    "patient_#{patient_id}_conditions"
  end

  def cache_key_for_patient_goals(patient_id)
    "patient_#{patient_id}_goals"
  end

  def cache_key_for_patient_medication_lists(patient_id)
    "patient_#{patient_id}_medication_lists"
  end

  def cache_key_for_patient_medication_requests(patient_id)
    "patient_#{patient_id}_medication_requests_#{session_id}"
  end

  def cache_key_for_patient_procedures(patient_id)
    "patient_#{patient_id}_procedures_#{session_id}"
  end

  def cache_key_for_patient_diagnostic_reports(patient_id)
    "patient_#{patient_id}_diagnostic_reports_#{session_id}"
  end

  def cache_key_for_patient_document_references(patient_id)
    "patient_#{patient_id}_document_references_#{session_id}"
  end

  def cache_key_for_patient_nutrition_orders(patient_id)
    "patient_#{patient_id}_nutrition_orders"
  end

  def cache_key_for_patient_observations(patient_id)
    "patient_#{patient_id}_observations"
  end

  def cache_key_for_patient_questionnaire_responses(patient_id)
    "patient_#{patient_id}_questionnaire_responses"
  end

  def cache_key_for_patient_service_requests(patient_id)
    "patient_#{patient_id}_service_requests"
  end

  def cache_key_for_patient_tocs(patient_id)
    "patient_#{patient_id}_tocs"
  end

  def cache_key_for_practioner_roles
    'practitioner_roles'
  end
end
