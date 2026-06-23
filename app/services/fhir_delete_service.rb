require 'net/http'
require 'uri'
require 'json'
require 'set'

class FhirDeleteService
  MAX_RETRIES = 5
  RESOURCE_ORDER = FhirPushService::RESOURCE_ORDER.freeze
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
    sorted_urls = sort_resource_urls_for_delete(@resource_urls)

    resources_to_process = sorted_urls.dup
    successful_resources = Set.new
    failed_resources = []
    retry_counts = Hash.new(0)

    update_task_status('Starting data delete...', 0, TaskStatus::RUNNING)

    until resources_to_process.empty?
      current_url = resources_to_process.shift
      next if successful_resources.include?(current_url)
      next if retry_counts[current_url] >= MAX_RETRIES

      retry_counts[current_url] += 1
      attempt_num = retry_counts[current_url]

      begin
        resource_json = fetch_resource(current_url)
        resource = JSON.parse(resource_json)

        unless resource.is_a?(Hash) && resource['resourceType'].present? && resource['id'].present?
          handle_failed_delete(
            current_url,
            'Invalid FHIR resource format',
            retry_counts,
            resources_to_process,
            failed_resources,
            force_fail: true
          )
          next
        end

        resource_type = resource['resourceType']
        resource_id = resource['id']
        resource_key = "#{resource_type}/#{resource_id}"

        message = "Deleting #{resource_key} with cascade... (Attempt #{attempt_num}/#{MAX_RETRIES})"
        update_task_status(message, successful_resources.size)

        uri = URI("#{@fhir_server_url}/#{resource_type}/#{resource_id}?_cascade=delete")
        request = Net::HTTP::Delete.new(uri)

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', read_timeout: HTTP_TIMEOUT) do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection) || response.code.to_i == 404
          successful_resources.add(current_url)
        else
          error_message = parse_error_response(response)
          handle_failed_delete(current_url, error_message, retry_counts, resources_to_process, failed_resources, resource_key: resource_key)
        end
      rescue StandardError => e
        handle_failed_delete(current_url, e.message, retry_counts, resources_to_process, failed_resources)
      end
    end

    finalize_status(successful_resources.size, failed_resources)
  end

  private

  def sort_resource_urls_for_delete(urls)
    urls.sort_by do |url|
      index = RESOURCE_ORDER.find_index { |resource_type| url.include?(resource_type) }
      index.nil? ? -1 : -index
    end
  end

  def fetch_resource(url)
    uri = URI(url)
    Net::HTTP.get(uri)
  end

  def handle_failed_delete(url, error_message, retry_counts, queue, failed_list, force_fail: false, resource_key: nil)
    if force_fail || retry_counts[url] >= MAX_RETRIES
      failed_list << { url: url, resource_key: resource_key, error: error_message }
    else
      queue.push(url)
    end
  end

  def update_task_status(message, success_count, status = TaskStatus::RUNNING)
    progress = @total_resources.zero? ? 100 : (success_count.to_f / @total_resources * 100).to_i
    progress_message = "[#{progress}%] #{message}"
    Rails.logger.info(progress_message) if Rails.env.development?
    @task_status.update_status(status, progress_message)
  end

  def finalize_status(success_count, failed_resources)
    if failed_resources.empty?
      message = "Delete completed successfully. #{success_count} resources deleted."
      update_task_status(message, success_count, TaskStatus::COMPLETED)
    else
      error_summary = failed_resources.map do |failure|
        "#{failure[:resource_key] || File.basename(failure[:url])}: #{failure[:error]}"
      end.join("\n")
      message = "Delete completed with #{failed_resources.size} failures:\n#{error_summary}"
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
    end

    response_body = response.body.to_s
    truncated_body = response_body.respond_to?(:truncate) ? response_body.truncate(500) : response_body[0...500]
    "HTTP Error #{response.code}: #{truncated_body}"
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
