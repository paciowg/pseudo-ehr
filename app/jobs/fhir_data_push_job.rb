class FhirDataPushJob < ApplicationJob
  queue_as :default

  def perform(release_tag, fhir_server_url, task_status_id)
    task_status = TaskStatus.find_by(id: task_status_id)
    unless task_status
      Rails.logger.error "FhirDataPushJob failed: unable to find task status for task status ID #{task_status_id}"
      return
    end

    begin
      task_status.mark_running("Fetching resource URLs for release: #{release_tag}")
      resource_urls = SampleDataService.version_resource_urls(release_tag)

      if resource_urls.empty?
        task_status.mark_failed("No resources found for release: #{release_tag}")
        return
      end

      FhirPushService.perform(resource_urls, fhir_server_url, task_status)
    rescue StandardError => e
      task_status.mark_failed("An unexpected error occurred: #{e.message}")
      Rails.logger.error "FhirDataPushJob failed for task #{task_status.id}: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end
