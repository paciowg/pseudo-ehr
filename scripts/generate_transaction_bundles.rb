#!/usr/bin/env ruby
require 'json'
require 'fileutils'

# Script to generate transation bundles for each scene in the sample data use case directory

# Base directory containing all scenes
base_dir = 'sample_use_cases/betsy_smith_johnson_stroke_use_case_pacio_sample_data_depot_v0_1_0'

# Process each scene directory
Dir.glob("#{base_dir}/scene_*").each do |scene_dir|
  scene_name = File.basename(scene_dir)
  puts "Processing #{scene_name}..."

  # Create a transaction bundle
  transaction_bundle = {
    'resourceType' => 'Bundle',
    'id' => "#{scene_name}-transaction-bundle",
    'type' => 'transaction',
    'timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
    'entry' => []
  }

  # Find all JSON files in the scene directory (recursively)
  json_files = Dir.glob("#{scene_dir}/**/*.json")

  # Skip existing Bundle files
  json_files.reject! { |file| file.include?('/Bundle/') }

  # Process each JSON file
  json_files.each do |file_path|
    # Read and parse the JSON file
    resource = JSON.parse(File.read(file_path))

    # Skip if not a FHIR resource or missing required fields
    next unless resource.is_a?(Hash) && resource['resourceType'] && resource['id']

    # Add the resource to the transaction bundle
    transaction_bundle['entry'] << {
      'fullUrl' => "urn:#{resource['id']}",
      'resource' => resource,
      'request' => {
        'method' => 'PUT',
        'url' => "#{resource['resourceType']}/#{resource['id']}"
      }
    }

    puts "  Added #{resource['resourceType']}/#{resource['id']} to transaction bundle"
  rescue JSON::ParserError => e
    puts "  Error parsing #{file_path}: #{e.message}"
  rescue StandardError => e
    puts "  Error processing #{file_path}: #{e.message}"
  end

  # Create the output directory if it doesn't exist
  output_dir = "#{scene_dir}/TransactionBundle"
  FileUtils.mkdir_p(output_dir)

  # Write the transaction bundle to a file
  output_file = "#{output_dir}/#{scene_name}-transaction-bundle.json"
  File.write(output_file, JSON.pretty_generate(transaction_bundle))

  puts "Created transaction bundle with #{transaction_bundle['entry'].size} resources: #{output_file}"
end

puts 'Done!'
