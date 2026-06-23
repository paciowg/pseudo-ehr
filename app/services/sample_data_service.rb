require 'net/http'
require 'json'
require 'openssl'

class SampleDataService
  class << self
    def manifest
      Rails.cache.fetch('sample_data_manifest', expires_in: 1.minute) do
        JSON.parse(fetch_uri(Rails.configuration.x.sample_data.manifest_url))
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
        JSON.pretty_generate(JSON.parse(fetch_uri(url)))
      end
    rescue StandardError => e
      Rails.logger.error "Failed to fetch or parse resource from #{url}: #{e.message}"
      { error: "Failed to fetch resource: #{e.message}" }.to_json
    end

    private

    def fetch_uri(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.cert_store = certificate_store if http.use_ssl?

      response = http.get(uri.request_uri)
      response.value
      response.body
    end

    def certificate_store
      store = OpenSSL::X509::Store.new
      store.set_default_paths
      # Homebrew OpenSSL can inherit CRL-check flags that require local CRLs for
      # public web certificates. Keep normal CA verification, but do not require CRLs.
      store.flags = 0 if store.respond_to?(:flags=)
      store
    end
  end
end
