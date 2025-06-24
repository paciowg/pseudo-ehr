require 'English'
class SampleDataController < ApplicationController
  skip_before_action :current_server, raise: false
  def index
    @use_cases = load_use_cases
    @selected_file_path = params[:path]

    if @selected_file_path && File.exist?(@selected_file_path)
      @file_content = File.read(@selected_file_path)
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

      # Escape special characters in the URL and folder path
      escaped_url = fhir_server_url.gsub(/[\\,]/, '\\\\\&')
      escaped_folder = folder_path.gsub(/[\\ ,]/, '\\\\\&')

      # Run the rake task in the background
      Thread.new do
        # Update task status to running
        task_status.mark_running("Pushing data from #{folder_path} to #{fhir_server_url}")

        # Execute the rake task
        command = "bundle exec rake \"fhir:push[#{escaped_url},#{escaped_folder}]\""
        Rails.logger.info "Executing command: #{command}"

        # Capture the output of the command
        output = `#{command} 2>&1`
        exit_status = $CHILD_STATUS.exitstatus

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
