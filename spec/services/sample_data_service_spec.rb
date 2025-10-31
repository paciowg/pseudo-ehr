require 'rails_helper'
require 'webmock/rspec'

RSpec.describe SampleDataService, type: :service do
  let(:manifest_url) { 'https://paciowg.github.io/sample-data-fsh/manifest.json' }
  let(:manifest_body) { file_fixture('sample_data_manifest.json').read }
  let(:resource_url) { 'https://paciowg.github.io/sample-data-fsh/pacio-sample-data/Organization-org-ED-Metro-Hospital.json' }
  let(:resource_content) { { resourceType: 'Organization', id: 'org-ED-Metro-Hospital' }.to_json }
  let(:parsed_manifest) { JSON.parse(manifest_body) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
    allow(Rails.configuration.x.sample_data).to receive(:manifest_url).and_return(manifest_url)
  end

  describe '.manifest' do
    context 'when fetch is successful' do
      before do
        stub_request(:get, manifest_url).to_return(status: 200, body: manifest_body, headers: {})
      end

      it 'fetches, parses, and caches the manifest' do
        expect(described_class.manifest).to eq(parsed_manifest)
        # Call again to ensure cache is used
        described_class.manifest
        expect(WebMock).to have_requested(:get, manifest_url).once
      end
    end

    context 'when fetch is unsuccessful' do
      it 'returns an empty hash and logs an error on 404' do
        stub_request(:get, manifest_url).to_return(status: 404)
        expect(Rails.logger).to receive(:error).with(/Failed to fetch or parse manifest.json/)
        expect(described_class.manifest).to eq({})
      end

      it 'returns an empty hash and logs an error on timeout' do
        stub_request(:get, manifest_url).to_timeout
        expect(Rails.logger).to receive(:error).with(/Failed to fetch or parse manifest.json/)
        expect(described_class.manifest).to eq({})
      end

      it 'returns an empty hash and logs an error on invalid JSON' do
        stub_request(:get, manifest_url).to_return(status: 200, body: 'invalid json')
        expect(Rails.logger).to receive(:error).with(/Failed to fetch or parse manifest.json/)
        expect(described_class.manifest).to eq({})
      end
    end
  end

  describe '.versions' do
    before do
      allow(described_class).to receive(:manifest).and_return(parsed_manifest)
    end

    it 'returns a formatted list of versions with parsed datetimes' do
      versions = described_class.versions
      expect(versions.size).to eq(2)
      expect(versions.first).to include(
        'identifier' => 'pacio-sample-data',
        'description' => 'PACIO Sample Data v0.2'
      )
      expect(versions.first['datetime']).to be_a(Time)
    end

    it 'handles a manifest with no versions' do
      allow(described_class).to receive(:manifest).and_return({})
      expect(described_class.versions).to eq([])
    end
  end

  describe '.version_data' do
    before do
      allow(described_class).to receive(:manifest).and_return(parsed_manifest)
    end

    it 'returns the data for a specific version identifier' do
      data = described_class.version_data('pacio-sample-data')
      expect(data['description']).to eq('PACIO Sample Data v0.2')
    end

    it 'returns an empty hash for a non-existent identifier' do
      expect(described_class.version_data('non-existent')).to eq({})
    end
  end

  describe '.version_resource_urls' do
    before do
      allow(described_class).to receive(:manifest).and_return(parsed_manifest)
    end

    it 'returns a flat list of all resource URLs for a version' do
      resources = described_class.version_resource_urls('pacio-sample-data')
      expected_resources = [
        'https://paciowg.github.io/sample-data-fsh/pacio-sample-data/Organization-org-ED-Metro-Hospital.json',
        'https://paciowg.github.io/sample-data-fsh/pacio-sample-data/Location-org-Loc-ACMEssential.json'
      ]
      expect(resources).to match_array(expected_resources)
    end

    it 'returns an empty array for a non-existent identifier' do
      expect(described_class.version_resource_urls('non-existent')).to eq([])
    end
  end

  describe '.fetch_resource' do
    context 'when fetch is successful' do
      let(:pretty_resource_content) { JSON.pretty_generate(JSON.parse(resource_content)) }

      before do
        stub_request(:get, resource_url).to_return(status: 200, body: resource_content, headers: {})
      end

      it 'fetches, pretty-prints, and caches the resource content' do
        expect(described_class.fetch_resource(resource_url)).to eq(pretty_resource_content)
        # Call again to ensure cache is used
        described_class.fetch_resource(resource_url)
        expect(WebMock).to have_requested(:get, resource_url).once
      end
    end

    context 'when fetch fails' do
      it 'returns an error JSON and logs an error on 404' do
        stub_request(:get, resource_url).to_return(status: 404)
        expect(Rails.logger).to receive(:error).with(/Failed to fetch or parse resource from/)
        result = described_class.fetch_resource(resource_url)
        expect(JSON.parse(result)['error']).to include('Failed to fetch resource')
      end

      it 'returns an error JSON and logs an error on timeout' do
        stub_request(:get, resource_url).to_timeout
        expect(Rails.logger).to receive(:error).with(/Failed to fetch or parse resource from/)
        result = described_class.fetch_resource(resource_url)
        expect(JSON.parse(result)['error']).to include('Failed to fetch resource')
      end
    end
  end
end
