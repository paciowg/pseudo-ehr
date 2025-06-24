require 'English'
class SampleDataController < ApplicationController
  skip_before_action :current_server, raise: false
  def index
    @use_cases = load_use_cases

    # Find the file in our pre-loaded use cases instead of using the path parameter directly
    @selected_file_path = nil
    @file_content = nil

    if params[:path].present?
      # Find the file in our pre-loaded use cases
      @use_cases.each_value do |scenes|
        scenes.each_value do |resource_types|
          resource_types.each_value do |resources|
            resources.each do |resource|
              if resource[:path] == params[:path]
                @selected_file_path = resource[:path]
                break
              end
            end
          end
        end
      end

      # Only read the file if it was found in our pre-loaded use cases
      # rubocop:disable Layout/LineLength
      if @selected_file_path && File.exist?(@selected_file_path) && File.file?(@selected_file_path) && @selected_file_path.end_with?('.json')
        # rubocop:enable Layout/LineLength
        # Read the file safely - we've already validated it's a JSON file in our whitelist
        @file_content = File.binread(@selected_file_path)
      else
        Rails.logger.error "Attempted to read non-JSON file: #{@selected_file_path}"
        # rubocop:disable Rails/I18nLocaleTexts
        flash.now[:alert] = 'Only JSON files can be viewed'
        # rubocop:enable Rails/I18nLocaleTexts
        @file_content = nil
      end
      begin
        @json_content = JSON.pretty_generate(JSON.parse(@file_content))
        Rails.logger.info "JSON content parsed successfully: #{@json_content.class}"
      rescue StandardError => e
        Rails.logger.error "Error parsing JSON: #{e.message}"
        @json_content = nil
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: @json_content }
    end
  end

  def load_data
    @use_cases = load_use_cases
    @fhir_server_url = params[:fhir_server_url]
    # Store the FHIR server URL in the session for persistence
    session[:fhir_server_url] = @fhir_server_url if @fhir_server_url.present?

    # Get all FHIR servers from the database
    @fhir_servers = FhirServer.order(:name)
  end

  def push_data
    fhir_server_url = params[:fhir_server_url] || session[:fhir_server_url]
    folder_path = params[:folder_path]

    # Always store the FHIR server URL in the session
    session[:fhir_server_url] = fhir_server_url if fhir_server_url.present?

    if fhir_server_url.present? && folder_path.present?
      # Create a task status record
      task_status = TaskStatus.create_for_task(
        'FHIR Data Push',
        folder_path,
        fhir_server_url
      )

      # Run the rake task in the background
      Thread.new do
        # Update task status to running
        task_status.mark_running("Pushing data from #{folder_path} to #{fhir_server_url}")

        # Execute the rake task using Rails runner to avoid command injection
        output = ''
        exit_status = 0

        begin
          # Use Rails runner to execute the rake task
          require 'rake'
          Rails.application.load_tasks

          # Invoke the rake task directly
          Rake::Task['fhir:push'].reenable
          Rake::Task['fhir:push'].invoke(fhir_server_url, folder_path)

          # Get the latest log file
          log_dir = Rails.root.join('log/fhir_push_logs')
          latest_log = Dir.glob(File.join(log_dir, '*.log')).max_by { |f| File.mtime(f) }

          # Read the log file and extract the summary
          if latest_log && File.exist?(latest_log)
            log_content = File.read(latest_log)
            summary_match = log_content.match(/Summary: .*/)
            output = summary_match ? summary_match[0] : 'Task completed successfully'
          else
            output = 'Task completed successfully'
          end
        rescue StandardError => e
          output = "Error: #{e.message}"
          exit_status = 1
        end

        if exit_status.zero?
          # Extract summary from output
          summary_line = output.lines.grep(/Summary:/).first&.strip || 'Task completed successfully'
          task_status.mark_completed(summary_line)
        else
          # Extract error message from output
          error_message = output.lines.grep(/Error:/).first&.strip || "Task failed with exit status #{exit_status}"
          task_status.mark_failed(error_message)
        end
      rescue StandardError => e
        # Handle any exceptions
        task_status.mark_failed("Error: #{e.message}")
        Rails.logger.error "Error executing rake task: #{e.message}\n#{e.backtrace.join("\n")}"
      end

      flash[:notice] = t('.notice', folder_path: folder_path, fhir_server_url: fhir_server_url)
    else
      flash[:alert] = t('.alert')
    end

    # Redirect back to the load data page with the FHIR server URL preserved
    redirect_to load_data_sample_data_path
  end

  private

  # Validate that the file path is within the sample_use_cases directory
  def valid_sample_file_path?(file_path)
    # Convert to absolute path and normalize
    absolute_path = File.expand_path(file_path)
    sample_dir = Rails.root.join('sample_use_cases').to_s

    # Check if the path is within the sample_use_cases directory
    absolute_path.start_with?(sample_dir) && absolute_path.exclude?('..')
  end

  def load_use_cases
    use_cases = {}

    # Get all use case directories
    use_case_dirs = Rails.root.glob('sample_use_cases/*').select { |f| File.directory?(f) }

    use_case_dirs.each do |use_case_dir|
      use_case_name = File.basename(use_case_dir)
      use_cases[use_case_name] = {}

      # Get all scene directories
      scene_dirs = Dir.glob(File.join(use_case_dir, '*')).select { |f| File.directory?(f) }

      scene_dirs.each do |scene_dir|
        scene_name = File.basename(scene_dir)
        use_cases[use_case_name][scene_name] = {}

        # Get all resource type directories
        resource_type_dirs = Dir.glob(File.join(scene_dir, '*')).select { |f| File.directory?(f) }

        resource_type_dirs.each do |resource_type_dir|
          resource_type = File.basename(resource_type_dir)

          # Get all JSON files
          json_files = Dir.glob(File.join(resource_type_dir, '*.json'))

          use_cases[use_case_name][scene_name][resource_type] = json_files.map do |file|
            {
              name: File.basename(file, '.json'),
              path: file
            }
          end
        end
      end
    end

    use_cases
  end
end
