class ConvertQrToPfeAndSubmitJob < ApplicationJob
  queue_as :default

  def perform(qr_hash, fhir_server_url, task_id, patient_id)
    task = TaskStatus.find_by(task_id: task_id)
    return unless task

    task.mark_running("Task #{task_id}: Converting QuestionnaireResponse to PFE Observations...")

    response = Faraday.post(Rails.application.routes.url_helpers.api_convert_qr_to_pfe_and_submit_url(
                              host: Rails.application.config.default_url_options[:host]
                            )) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        questionnaire_response: qr_hash,
        fhir_server: fhir_server_url
      }.to_json
    end

    if response.success?
      body = JSON.parse(response.body)
      fhir_bundle = FHIR.from_contents(body['resource'].to_json)
      observations = fhir_bundle.entry.map(&:resource).select { |r| r.resourceType == 'Observation' }
      PatientRecordCache.update_patient_record(patient_id, observations)
      patient_record = PatientRecordCache.get_patient_record(patient_id)

      observations.each { |obs| Observation.new(obs, patient_record) }

      task.mark_completed("Task #{task_id}: Conversion completed successfully.")
    else
      body = begin
        JSON.parse(response.body)
      rescue StandardError
        {}
      end
      task.mark_failed("Task #{task_id}: Conversion failed: #{body['error'] || response.status}")
    end
  rescue StandardError => e
    task&.mark_failed("Unexpected error: #{e.message}")
    Rails.logger.error("[QR Conversion Job] #{e.message}")
  end
end
