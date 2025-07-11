require 'json'
require 'fileutils'

namespace :resources do
  desc 'Check resource references and ensure referenced resources are present in scenes'
  task check_references: :environment do
    # Path to the sample use cases directory
    sample_use_cases_dir = Rails.root.join('sample_use_cases').to_s
    # Path to the data directory containing all resources
    data_dir = Rails.root.join('data').to_s

    # Get all use case directories
    use_case_dirs = Dir.glob(File.join(sample_use_cases_dir, '*')).select { |f| File.directory?(f) }

    use_case_dirs.each do |use_case_dir|
      puts "Processing use case: #{File.basename(use_case_dir)}"

      # Get all scene directories sorted by scene number
      scene_dirs = Dir.glob(File.join(use_case_dir, 'scene_*')).select { |f| File.directory?(f) }
                      .sort_by { |dir| dir.match(/scene_(\d+)/)[1].to_i }

      # Keep track of all resources we've seen so far across all scenes
      all_resources = {}

      scene_dirs.each do |scene_dir|
        scene_num = File.basename(scene_dir).match(/scene_(\d+)/)[1].to_i
        puts "  Processing scene #{scene_num}"

        # Get all resource type directories in this scene
        resource_type_dirs = Dir.glob(File.join(scene_dir, '*')).select { |f| File.directory?(f) }

        # Track resources in this scene by resource type
        scene_resources = {}

        # First pass: collect all resources in this scene
        resource_type_dirs.each do |resource_type_dir|
          resource_type = File.basename(resource_type_dir)
          scene_resources[resource_type] ||= []

          resource_files = Dir.glob(File.join(resource_type_dir, '*.json'))
          resource_files.each do |resource_file|
            resource_id = File.basename(resource_file, '.json')
            # Add to scene resources
            scene_resources[resource_type] << resource_id
            # Add to all resources with full reference path
            all_resources["#{resource_type}/#{resource_id}"] = {
              scene: scene_num,
              path: resource_file
            }
          end

          # Second pass: check references in each resource
          File.basename(resource_type_dir)

          resource_files = Dir.glob(File.join(resource_type_dir, '*.json'))
          resource_files.each do |resource_file|
            resource_data = JSON.parse(File.read(resource_file))
            resource_data['id']

            # Find all references in the resource
            references = find_references(resource_data)

            references.each do |reference|
              # Skip if the reference is already in this scene or a previous scene
              next if reference_exists?(reference, all_resources)

              # If not found, look for it in the data directory
              data_file = find_in_data_dir(reference, data_dir)
              if data_file
                # Extract resource type and id from the reference
                if reference.include?('/')
                  ref_type, ref_id = reference.split('/')
                else
                  # If reference doesn't include type, try to determine from filename
                  ref_id = reference
                  ref_type = determine_resource_type_from_file(data_file)
                end

                # Create directory for this resource type if it doesn't exist
                target_dir = File.join(scene_dir, ref_type)
                FileUtils.mkdir_p(target_dir)

                # Copy the resource to the scene
                target_file = File.join(target_dir, "#{ref_id}.json")
                FileUtils.cp(data_file, target_file)

                puts "    Added missing resource #{reference} to scene #{scene_num}"

                # Update our tracking
                scene_resources[ref_type] ||= []
                scene_resources[ref_type] << ref_id
                all_resources["#{ref_type}/#{ref_id}"] = {
                  scene: scene_num,
                  path: target_file
                }
              else
                puts "    WARNING: Referenced resource #{reference} not found in data directory"
              end
            end
          rescue JSON::ParserError => e
            puts "    ERROR: Failed to parse JSON in #{resource_file}: #{e.message}"
          end
        end
      end
    end
  end

  # Find all references in a resource recursively
  def find_references(data, references = [])
    if data.is_a?(Hash)
      # Check for reference field
      references << data['reference'] if data.key?('reference') && data['reference'].is_a?(String)

      # Recursively check all hash values
      data.each_value do |value|
        find_references(value, references)
      end
    elsif data.is_a?(Array)
      # Recursively check all array elements
      data.each do |item|
        find_references(item, references)
      end
    end

    references
  end

  # Check if a reference exists in the collected resources
  def reference_exists?(reference, all_resources)
    # Handle both formats: "ResourceType/id" and just "id"
    return all_resources.key?(reference) if reference.include?('/')

    # If just an ID is provided, check if any resource with this ID exists
    all_resources.any? { |key, _| key.end_with?("/#{reference}") }
  end

  # Find a resource in the data directory
  def find_in_data_dir(reference, data_dir)
    if reference.include?('/')
      # If reference includes resource type, look for exact match
      ref_type, ref_id = reference.split('/')
      potential_file = File.join(data_dir, "#{ref_type}-#{ref_id}.json")
      return potential_file if File.exist?(potential_file)

      # Also try with just the ID
      potential_files = Dir.glob(File.join(data_dir, "*-#{ref_id}.json"))
    else
      # If reference is just an ID, look for any file with this ID
      potential_files = Dir.glob(File.join(data_dir, "*-#{reference}.json"))
    end
    return potential_files.first unless potential_files.empty?

    nil
  end

  # Try to determine resource type from filename
  def determine_resource_type_from_file(file_path)
    filename = File.basename(file_path, '.json')
    return filename.split('-').first if filename.include?('-')

    # Default to Unknown if we can't determine
    'Unknown'
  end
end
