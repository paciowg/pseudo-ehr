require 'rails_helper'

RSpec.describe SampleDataController, type: :request do
  include ActiveJob::TestHelper

  let(:sample_versions) do
    [
      { 'identifier' => 'v1.0.0', 'description' => 'Version 1.0.0', 'datetime' => Time.now.iso8601 },
      { 'identifier' => 'v2.0.0', 'description' => 'Version 2.0.0', 'datetime' => Time.now.iso8601 }
    ]
  end

  let(:sample_version_data) do
    {
      'scenes' => [
        { 'name' => 'Scene 1', 'resources' => ['http://example.com/patient.json'] },
        { 'name' => 'Scene 2', 'resources' => [] }
      ]
    }
  end

  before do
    # Stub the SampleDataService to return predictable data
    allow(SampleDataService).to receive(:versions).and_return(sample_versions)
    allow(SampleDataService).to receive(:version_data).with(anything).and_return(sample_version_data)
  end

  describe 'GET #index' do
    context 'when viewing the list of scenes and resources' do
      it 'renders the index template and assigns instance variables' do
        get sample_data_path
        expect(response).to have_http_status(:ok)
        expect(assigns(:releases)).to eq(sample_versions)
        expect(assigns(:scenes)).to eq(sample_version_data['scenes'])
      end

      it 'fetches data for a specific release tag if provided' do
        get sample_data_path, params: { release_tag: 'v2.0.0' }
        expect(SampleDataService).to have_received(:version_data).with('v2.0.0')
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET #show_file' do
    let(:release_tag) { 'v1.0.0' }
    let(:resource_url) { 'http://example.com/patient.json' }
    let(:resource_content) { { 'resourceType' => 'Patient', 'id' => '123' }.to_json }

    context 'with a valid resource URL' do
      before do
        allow(SampleDataService).to receive(:version_resource_urls).with(release_tag).and_return([resource_url])
        allow(SampleDataService).to receive(:fetch_resource).with(resource_url).and_return(resource_content)
      end

      it 'fetches and assigns the content of the resource' do
        get show_file_sample_data_path, params: { resource_url: resource_url, release_tag: release_tag }

        expect(response).to have_http_status(:ok)
        expect(assigns(:file_content)).to eq(resource_content)
        expect(assigns(:json_content)).to eq(JSON.pretty_generate(JSON.parse(resource_content)))
      end
    end

    context 'with an invalid resource URL' do
      let(:invalid_url) { 'http://example.com/invalid.json' }

      before do
        allow(SampleDataService).to receive(:version_resource_urls).with(release_tag).and_return([resource_url])
      end

      it 'returns an unprocessable_entity status' do
        get show_file_sample_data_path, params: { resource_url: invalid_url, release_tag: release_tag }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST #push_data' do
    let(:fhir_server_url) { 'http://example.com/fhir' }
    let(:release_tag) { 'v1.0.0' }

    context 'with valid parameters' do
      before do
        allow_any_instance_of(described_class).to receive(:session).and_return({ fhir_server_url: fhir_server_url })
      end

      it 'creates a TaskStatus, enqueues a job, and redirects' do
        expect do
          post push_data_sample_data_path, params: { release_tag: release_tag }
        end.to change(TaskStatus, :count).by(1)

        task_status = TaskStatus.last
        expect(task_status.task_type).to eq('FHIR Data Push')

        expect(FhirDataPushJob).to have_been_enqueued.with(release_tag, fhir_server_url, task_status.id)

        expect(response).to redirect_to(sample_data_path(release_tag: release_tag, task_id: task_status.task_id))
      end
    end

    context 'with missing parameters' do
      it 'does not create a TaskStatus or enqueue a job, and redirects with an alert' do
        expect do
          post push_data_sample_data_path, params: { release_tag: '' }
        end.not_to change(TaskStatus, :count)

        expect(FhirDataPushJob).not_to have_been_enqueued

        expect(response).to redirect_to(sample_data_path(release_tag: ''))
        expect(flash[:alert]).to be_present
      end
    end
  end
end
