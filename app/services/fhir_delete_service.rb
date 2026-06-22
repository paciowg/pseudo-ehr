require 'net/http'
require 'uri'
require 'json'
require 'set'

class FhirDeleteService
  MAX_RETRIES = 5
  RESOURCE_ORDER = FhirPushService::RESOURCE_ORDER.freeze
  HTTP_TIMEOUT = 30 # seconds

  def self.perform(resource_references, fhir_server_url, task_status)
    new(resource_references, fhir_server_url, task_status).perform
  end

  def initialize(resource_references, fhir_server_url, task_status)
    @resource_references = deduplicate_references(resource_references)
    @fhir_server_url = fhir_server_url.chomp('/')
    @task_status = task_status
    @total_resources = @resource_references.size
  end

  def perform
    sorted_references = sort_resource_references_for_delete(@resource_references)

    resources_to_process = sorted_references.dup
    successful_resources = Set.new
    failed_resources = []
    retry_counts = Hash.new(0)

    update_task_status('Starting data delete...', 0, TaskStatus::RUNNING)

    until resources_to_process.empty?
      current_reference = resources_to_process.shift
      reference_key = resource_key(current_reference)
      next if successful_resources.include?(reference_key)
      next if retry_counts[reference_key] >= MAX_RETRIES

      retry_counts[reference_key] += 1
      attempt_num = retry_counts[reference_key]

      resource_type = current_reference[:resource_type]
      resource_id = current_reference[:resource_id]

      if resource_type.blank? || resource_id.blank?
        handle_failed_delete(
          current_reference,
          'Invalid resource reference format',
          retry_counts,
          resources_to_process,
          failed_resources,
          force_fail: true
        )
        next
      end

      message = "Deleting #{reference_key} with cascade... (Attempt #{attempt_num}/#{MAX_RETRIES})"
      update_task_status(message, successful_resources.size)

      uri = URI("#{@fhir_server_url}/#{resource_type}/#{resource_id}?_cascade=delete")
      request = Net::HTTP::Delete.new(uri)

      begin
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', read_timeout: HTTP_TIMEOUT) do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection) || response.code.to_i == 404
          successful_resources.add(reference_key)
        else
          error_message = parse_error_response(response)
          handle_failed_delete(current_reference, error_message, retry_counts, resources_to_process, failed_resources)
        end
      rescue StandardError => e
        handle_failed_delete(current_reference, e.message, retry_counts, resources_to_process, failed_resources)
      end
    end

    finalize_status(successful_resources.size, failed_resources)
  end

  private

  def deduplicate_references(resource_references)
    resource_references.uniq { |reference| resource_key(reference) }
  end

  def sort_resource_references_for_delete(references)
    references.sort_by do |reference|
      resource_type = reference[:resource_type]
      index = RESOURCE_ORDER.find_index(resource_type)
      index.nil? ? -1 : -index
    end
  end

  def resource_key(reference)
    "#{reference[:resource_type]}/#{reference[:resource_id]}"
  end

  def handle_failed_delete(reference, error_message, retry_counts, queue, failed_list, force_fail: false)
    key = resource_key(reference)
    if force_fail || retry_counts[key] >= MAX_RETRIES
      failed_list << { reference: reference, error: error_message }
    else
      queue.push(reference)
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
        "#{resource_key(failure[:reference])}: #{failure[:error]}"
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
