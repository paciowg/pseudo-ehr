class SampleDataController < ApplicationController
  skip_before_action :current_server, raise: false
  before_action :delete_current_patient_id

  def index
    @releases = SampleDataService.versions || []
    @selected_release_tag = params[:release_tag] || @releases.first&.dig('identifier')
    version_data = SampleDataService.version_data(@selected_release_tag)
    @scenes = version_data.fetch('scenes', [])
    @other_resources = version_data.fetch('other_resources', [])
    @task_status = TaskStatus.find_by(task_id: params[:task_id]) if params[:task_id].present?
  end

  def show_file
    release_tag = params[:release_tag]
    resource_url = params[:resource_url]

    # Security: Ensure the requested URL is part of the specified release manifest
    valid_urls = SampleDataService.version_resource_urls(release_tag)
    unless valid_urls.include?(resource_url)
      render plain: 'Error: Invalid resource URL.', status: :unprocessable_entity
      return
    end

    @file_name = File.basename(URI.parse(resource_url).path)
    @file_content = SampleDataService.fetch_resource(resource_url)
    @json_content = JSON.pretty_generate(JSON.parse(@file_content))
  rescue StandardError => e
    Rails.logger.error "Error fetching or parsing resource from #{resource_url}: #{e.message}"
    @json_content = { error: "Failed to display resource: #{e.message}" }.to_json
  end

  def push_data
    fhir_server_url = session[:fhir_server_url]
    release_tag = params[:release_tag]

    if fhir_server_url.present? && release_tag.present?
      task_status = TaskStatus.create_for_task('FHIR Data Push')
      FhirDataPushJob.perform_later(release_tag, fhir_server_url, task_status.id)
      redirect_to sample_data_path(release_tag: release_tag, task_id: task_status.task_id)
    else
      flash[:alert] = 'Please select a FHIR server and a release version.'
      redirect_to sample_data_path(release_tag: release_tag)
    end
  end
end
