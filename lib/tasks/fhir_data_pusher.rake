require 'json'
require 'net/http'
require 'uri'
require 'fileutils'
require 'time'

namespace :fhir do
  desc 'Push FHIR resources to a FHIR server in the correct dependency order'
  task :push, %i[server_url folder_path] => :environment do |_t, args|
    server_url = args[:server_url]
    folder_path = args[:folder_path]

    if server_url.nil? || folder_path.nil?
      puts 'Usage: bundle exec rake fhir:push[server_url,folder_path]'
      puts 'Example: bundle exec rake fhir:push[http://hapi.fhir.org/baseR4,sample_use_cases/Betsy\\ Smith-Johnson]'
      exit 1
    end

    # Normalize server URL (remove trailing slash if present)
    server_url = server_url.chomp('/')

    # Create log file in the project's log directory
    timestamp = Time.zone.now.strftime('%Y%m%d_%H%M%S')
    log_dir = Rails.root.join('log/fhir_push_logs')
    FileUtils.mkdir_p(log_dir)
    log_file_path = "#{log_dir}/fhir_push_#{timestamp}.log"
    log_file = File.open(log_file_path, 'w')

    log_message("Starting to push FHIR resources from #{folder_path} to #{server_url}", log_file)

    # Find all JSON files in the folder (recursively)
    json_files = Dir.glob(File.join(folder_path, '**', '*.json'))
    log_message("Found #{json_files.length} JSON files", log_file)

    if json_files.empty?
      log_message("No JSON files found in #{folder_path}", log_file)
      log_file.close
      exit 1
    end

    # Parse all JSON files and build a dependency graph
    resources = {}
    dependencies = {}

    json_files.each do |file_path|
      json_content = File.read(file_path)
      resource = JSON.parse(json_content)

      # Skip if not a valid FHIR resource
      next unless resource.is_a?(Hash) && resource['resourceType'] && resource['id']

      resource_key = "#{resource['resourceType']}/#{resource['id']}"
      resources[resource_key] = {
        path: file_path,
        data: resource
      }

      # Initialize dependencies for this resource
      dependencies[resource_key] = Set.new

      # Extract references to other resources
      extract_references(resource, dependencies[resource_key])
    rescue StandardError => e
      log_message("Error parsing #{file_path}: #{e.message}", log_file)
    end

    log_message("Parsed #{resources.length} valid FHIR resources", log_file)

    # Remove dependencies that don't exist in our resource set
    dependencies.each_value do |refs|
      refs.select! { |ref| resources.key?(ref) }
    end

    # Perform topological sort to determine the order of resources to push
    sorted_resources = topological_sort(resources.keys, dependencies)

    if sorted_resources.nil?
      log_message('Error: Circular dependencies detected. Cannot determine a valid order to push resources.', log_file)
      log_file.close
      exit 1
    end

    # Push resources in the sorted order
    successful_resources = Set.new
    failed_resources = []

    # Track retry attempts for each resource
    retry_counts = {}
    max_retries = 5

    # First pass: try to push all resources
    resources_to_process = sorted_resources.dup

    until resources_to_process.empty?
      current_resource = resources_to_process.shift

      # Skip if this resource has already been successfully pushed
      next if successful_resources.include?(current_resource)

      retry_counts[current_resource] ||= 0

      # Skip if we've already tried this resource too many times
      next if retry_counts[current_resource] >= max_retries

      retry_counts[current_resource] += 1
      attempt_num = retry_counts[current_resource]

      resource_info = resources[current_resource]
      resource_type, resource_id = current_resource.split('/')

      log_message("Pushing #{current_resource}... (Attempt #{attempt_num}/#{max_retries})", log_file)

      begin
        # Create the PUT request
        uri = URI("#{server_url}/#{resource_type}/#{resource_id}")
        request = Net::HTTP::Put.new(uri)
        request['Content-Type'] = 'application/fhir+json'
        request.body = JSON.generate(resource_info[:data])

        # Send the request
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end

        if response.code.to_i >= 200 && response.code.to_i < 300
          log_message("  Success: #{response.code}", log_file)
          successful_resources.add(current_resource)
        else
          # Try to parse the response as a FHIR OperationOutcome
          error_message = "HTTP Error: #{response.code}"

          begin
            outcome = JSON.parse(response.body)
            if outcome['resourceType'] == 'OperationOutcome' && outcome['issue']
              # Extract error messages from OperationOutcome
              issues = outcome['issue'].map do |issue|
                severity = issue['severity'] || 'unknown'
                code = issue['code'] || 'unknown'
                details = issue['details'] ? (issue['details']['text'] || 'No details') : 'No details'
                "#{severity} (#{code}): #{details}"
              end

              error_message = issues.join('; ')
            end
          rescue StandardError => e
            # If we can't parse the response as JSON or extract the error message,
            # just use the response body as the error message
            error_message = "Error parsing response: #{e.message}. Raw response: #{response.body[0..500]}"
          end

          log_message("  Failed: #{current_resource} - #{error_message}", log_file)

          # Add to failed resources if this was the last attempt
          if retry_counts[current_resource] >= max_retries
            failed_resources << {
              resource_key: current_resource,
              error: error_message,
              attempts: retry_counts[current_resource]
            }
          else
            # Add back to the queue for retry
            resources_to_process.push(current_resource)
          end
        end
      rescue StandardError => e
        log_message("  Error: #{current_resource} - #{e.message}", log_file)

        # Add to failed resources if this was the last attempt
        if retry_counts[current_resource] >= max_retries
          failed_resources << {
            resource_key: current_resource,
            error: e.message,
            attempts: retry_counts[current_resource]
          }
        else
          # Add back to the queue for retry
          resources_to_process.push(current_resource)
        end
      end
    end

    log_message('Completed pushing FHIR resources', log_file)
    log_message(
      "Summary: #{successful_resources.size} succeeded, #{failed_resources.size} failed (out of #{resources.size} total resources)", log_file
    )

    if failed_resources.size.positive?
      log_message("\nFailed Resources (after #{max_retries} attempts):", log_file)
      failed_resources.each do |failure|
        log_message("  #{failure[:resource_key]}: #{failure[:error]}", log_file)
      end
    end

    log_message("\nLog file saved to: #{log_file_path}", log_file)
    log_file.close

    puts 'Completed pushing FHIR resources'
    puts "Summary: #{successful_resources.size} succeeded, #{failed_resources.size} failed (out of #{resources.size} total resources)"
    puts "Log file saved to: #{log_file_path}"
  end

  # Helper method to log messages to both console and log file
  def log_message(message, log_file)
    puts message
    log_file.puts "[#{Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')}] #{message}"
  end

  # Helper method to extract references from a FHIR resource
  def extract_references(obj, refs, path = [])
    case obj
    when Hash
      # Check if this is a reference
      if obj['reference'].is_a?(String) && !obj['reference'].start_with?('#')
        # Add to references if it's not an internal reference
        refs.add(obj['reference'])
      end

      # Recursively process all hash values
      obj.each do |key, value|
        extract_references(value, refs, path + [key])
      end
    when Array
      # Recursively process all array elements
      obj.each_with_index do |value, index|
        extract_references(value, refs, path + [index])
      end
    end
  end

  # Perform topological sort on the dependency graph
  def topological_sort(nodes, edges)
    # Create a copy of the edges to avoid modifying the original
    edges = edges.transform_values(&:clone)

    # Find nodes with no dependencies
    result = []
    no_deps = nodes.select { |node| edges[node].empty? }

    until no_deps.empty?
      # Add a node with no dependencies to the result
      node = no_deps.shift
      result << node

      # Remove this node from the dependencies of other nodes
      edges.each do |dependent, deps|
        deps.delete(node)

        # If a node has no more dependencies, add it to no_deps
        no_deps << dependent if deps.empty? && result.exclude?(dependent)
      end
    end

    # If there are still edges, there's a cycle
    return nil if edges.any? { |_, deps| !deps.empty? }

    result
  end
end
