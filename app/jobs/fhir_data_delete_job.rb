class FhirDataDeleteJob < ApplicationJob
  queue_as :default

  def perform(release_tag, fhir_server_url, task_status_id)
    task_status = TaskStatus.find_by(id: task_status_id)
    unless task_status
      Rails.logger.error "FhirDataDeleteJob failed: unable to find task status for task status ID #{task_status_id}"
      return
    end

    begin
      task_status.mark_running("Fetching resource references for release: #{release_tag}")
      resource_references = SampleDataService.version_resource_references(release_tag, fhir_server_url)

      if resource_references.empty?
        task_status.mark_failed("No resources found for release: #{release_tag}")
        return
      end

      FhirDeleteService.perform(resource_references, fhir_server_url, task_status)
    rescue StandardError => e
      task_status.mark_failed("An unexpected error occurred: #{e.message}")
      Rails.logger.error "FhirDataDeleteJob failed for task #{task_status.id}: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end
