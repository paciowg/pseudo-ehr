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
  end
end
