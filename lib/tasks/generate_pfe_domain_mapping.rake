# lib/tasks/generate_pfe_domain_mapping.rake
require 'json'
require 'rest-client'
require 'yaml'

namespace :pfe do
  desc 'Generate PFE domain mapping from CodeSystem JSON'
  task generate_domain_mapping: :environment do
    url = 'https://hl7.org/fhir/us/pacio-pfe/CodeSystem-pfe-category-cs.json'
    puts "📥 Fetching CodeSystem from #{url}"

    begin
      response = RestClient.get(url)
      raw_json = response.body
    rescue RestClient::ExceptionWithResponse => e
      puts "❌ Failed to fetch CodeSystem: #{e.response}"
      exit 1
    rescue StandardError => e
      puts "❌ Unexpected error: #{e.message}"
      exit 1
    end

    json = JSON.parse(raw_json)
    root_concepts = json['concept'] || []

    mapping = {}

    # Recursively process all concepts and sub-concepts
    def extract_concepts(concepts, mapping)
      concepts.each do |concept|
        code = concept['code']
        display = concept['display']
        definition = concept['definition']

        if code && display
          mapping[code] = {
            'display' => display,
            'definition' => definition
          }
        end

        extract_concepts(concept['concept'], mapping) if concept['concept'].is_a?(Array)
      end
    end

    extract_concepts(root_concepts, mapping)

    output_path = Rails.root.join('config/pfe_domain_mapping.yml')
    File.write(output_path, mapping.to_yaml)

    puts "✅ #{mapping.keys.size} domain codes written to #{output_path}"
  end
end
