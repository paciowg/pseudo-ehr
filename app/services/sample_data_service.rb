require 'net/http'
require 'json'

class SampleDataService
  class << self
    def manifest
      Rails.cache.fetch('sample_data_manifest', expires_in: 1.minute) do
        uri = URI(Rails.configuration.x.sample_data.manifest_url)
        response = Net::HTTP.get(uri)
        JSON.parse(response)
      end
    rescue StandardError => e
      Rails.logger.error "Failed to fetch or parse manifest.json: #{e.message}"
      {}
    end

    def versions
      manifest.fetch('versions', []).map do |version|
        version.slice('type', 'identifier', 'description').merge('datetime' => begin
          Time.zone.parse(version['datetime'])
        rescue StandardError
          nil
        end)
      end
    end

    def version_data(identifier)
      manifest.fetch('versions', []).find { |v| v['identifier'] == identifier } || {}
    end

    def version_resource_urls(identifier)
      data = version_data(identifier)
      return [] if data.empty?

      scene_resources = data.fetch('scenes', []).flat_map { |scene| scene.fetch('resources', []) }
      other_resources = data.fetch('other_resources', [])
      scene_resources + other_resources
    end

    def version_resource_references(identifier, _fhir_server_url = nil)
      manifest_references = version_resource_urls(identifier).filter_map do |url|
        resource = fetch_resource_hash(url)
        next unless resource.is_a?(Hash)
        next if resource['resourceType'].blank? || resource['id'].blank?

        {
          resource_type: resource['resourceType'],
          resource_id: resource['id'],
          source_url: url,
          source: 'manifest'
        }
      end

      deduplicate_resource_references(manifest_references)
    end

    def fetch_resource(url)
      Rails.cache.fetch("sample_resource_content_#{url}", expires_in: 1.minute) do
        uri = URI(url)
        response = Net::HTTP.get(uri)
        JSON.pretty_generate(JSON.parse(response))
      end
    rescue StandardError => e
      Rails.logger.error "Failed to fetch or parse resource from #{url}: #{e.message}"
      { error: "Failed to fetch resource: #{e.message}" }.to_json
    end

    def fetch_resource_hash(url)
      Rails.cache.fetch("sample_resource_hash_#{url}", expires_in: 1.minute) do
        uri = URI(url)
        response = Net::HTTP.get(uri)
        JSON.parse(response)
      end
    rescue StandardError => e
      Rails.logger.error "Failed to fetch or parse resource hash from #{url}: #{e.message}"
      nil
    end

    private

    def deduplicate_resource_references(references)
      references.uniq { |reference| "#{reference[:resource_type]}/#{reference[:resource_id]}" }
    end
  end
end
