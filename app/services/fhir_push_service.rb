require 'net/http'
require 'uri'
require 'json'

# TODO: If auth needed refactor this to use client from fhir_client_service.rb

# Service to push a set of FHIR resources to a server.
# It handles retries and updates a TaskStatus record with progress.
class FhirPushService
  MAX_RETRIES = 5
  # Try to push resources that are less likely to have dependencies first.
  RESOURCE_ORDER = %w[Location Practitioner Patient].freeze
  HTTP_TIMEOUT = 30 # seconds

  def self.perform(resource_urls, fhir_server_url, task_status)
    new(resource_urls, fhir_server_url, task_status).perform
  end

  def initialize(resource_urls, fhir_server_url, task_status)
    @resource_urls = resource_urls.uniq
    @fhir_server_url = fhir_server_url.chomp('/')
    @task_status = task_status
    @total_resources = @resource_urls.size
  end

  def perform
    sorted_urls = sort_resource_urls(@resource_urls)

    resources_to_process = sorted_urls.dup
    successful_resources = Set.new
    failed_resources = []
    retry_counts = Hash.new(0)

    update_task_status('Starting data push...', 0, TaskStatus::RUNNING)

    until resources_to_process.empty?
      current_url = resources_to_process.shift
      next if successful_resources.include?(current_url)

      next if retry_counts[current_url] >= MAX_RETRIES

      retry_counts[current_url] += 1
      attempt_num = retry_counts[current_url]

      begin
        resource_json = fetch_resource(current_url)
        resource = JSON.parse(resource_json)

        unless resource.is_a?(Hash) && resource['resourceType'] && resource['id']
          handle_failed_push(current_url, 'Invalid FHIR resource format', retry_counts, resources_to_process, failed_resources, force_fail: true)
          next
        end

        resource_type = resource['resourceType']
        resource_id = resource['id']
        resource_key = "#{resource_type}/#{resource_id}"

        message = "Pushing #{resource_key}... (Attempt #{attempt_num}/#{MAX_RETRIES})"
        update_task_status(message, successful_resources.size)

        uri = URI("#{@fhir_server_url}/#{resource_type}/#{resource_id}")
        request = Net::HTTP::Put.new(uri)
        request['Content-Type'] = 'application/fhir+json'
        request.body = JSON.generate(resource)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', read_timeout: HTTP_TIMEOUT) do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess)
          successful_resources.add(current_url)
        else
          error_message = parse_error_response(response)
          handle_failed_push(current_url, error_message, retry_counts, resources_to_process, failed_resources)
        end
      rescue StandardError => e
        handle_failed_push(current_url, e.message, retry_counts, resources_to_process, failed_resources)
      end
    end

    finalize_status(successful_resources.size, failed_resources)
  end

  private

  def sort_resource_urls(urls)
    # A simple sort to handle common dependencies. e.g., Patient depends on Practitioner.
    urls.sort_by do |url|
      RESOURCE_ORDER.find_index { |resource_type| url.include?(resource_type) } || RESOURCE_ORDER.length
    end
  end

  def fetch_resource(url)
    uri = URI(url)
    Net::HTTP.get(uri)
  end

  def handle_failed_push(url, error_message, retry_counts, queue, failed_list, force_fail: false)
    if force_fail || retry_counts[url] >= MAX_RETRIES
      failed_list << { url: url, error: error_message }
    else
      queue.push(url)
    end
  end

  def update_task_status(message, success_count, status = TaskStatus::RUNNING)
    progress = @total_resources.zero? ? 100 : (success_count.to_f / @total_resources * 100).to_i
    progress_message = "[#{progress}%] #{message}"
    Rails.logger.info(progress_message) if Rails.env.development?
    @task_status.update_status(status, progress_message) # This updates the status and broadcasts
  end

  def finalize_status(success_count, failed_resources)
    if failed_resources.empty?
      message = "Push completed successfully. #{success_count} resources pushed."
      update_task_status(message, success_count, TaskStatus::COMPLETED)
    else
      error_summary = failed_resources.map { |f| "- #{File.basename(f[:url])}: #{f[:error]}" }.join("\n")
      message = "Push completed with #{failed_resources.size} failures:\n#{error_summary}"
      update_task_status(message, success_count, TaskStatus::FAILED)
    end
  end

  def parse_error_response(response)
    begin
      outcome = JSON.parse(response.body)
      if outcome['resourceType'] == 'OperationOutcome' && outcome['issue']
        return extract_operation_outcome_issues(outcome).join('; ')
      end
    rescue JSON::ParserError
      # Not a JSON response, fall through to return truncated body
    end
    "HTTP Error #{response.code}: #{response.body.truncate(500)}"
  end

  def extract_operation_outcome_issues(outcome)
    outcome['issue'].map do |issue|
      severity = issue['severity'] || 'unknown'
      code = issue['code'] || 'unknown'
      details = extract_issue_details(issue)
      "#{severity} (#{code}): #{details}"
    end
  end

  def extract_issue_details(issue)
    if issue.dig('details', 'text')
      issue['details']['text']
    elsif issue['diagnostics']
      issue['diagnostics']
    else
      'No details available'
    end
  end
end
