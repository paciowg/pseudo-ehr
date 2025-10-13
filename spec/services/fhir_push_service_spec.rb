require 'rails_helper'
require 'webmock/rspec'

RSpec.describe FhirPushService, type: :service do
  subject(:service) { described_class.new(resource_urls, fhir_server_url, task_status) }

  let(:fhir_server_url) { 'http://example.com/fhir' }
  let(:task_status) { instance_double(TaskStatus, update_status: nil) }
  let(:resource_urls) do
    [
      'http://example.com/resources/Patient/patient1',
      'http://example.com/resources/Practitioner/practitioner1'
    ]
  end
  let(:patient_resource) { { 'resourceType' => 'Patient', 'id' => 'patient1' }.to_json }
  let(:practitioner_resource) { { 'resourceType' => 'Practitioner', 'id' => 'practitioner1' }.to_json }

  before do
    # Stub resource fetching
    stub_request(:get, 'http://example.com/resources/Patient/patient1').to_return(body: patient_resource)
    stub_request(:get, 'http://example.com/resources/Practitioner/practitioner1').to_return(body: practitioner_resource)

    # Stub FHIR server PUT requests to succeed by default
    stub_request(:put, "#{fhir_server_url}/Patient/patient1").to_return(status: 200)
    stub_request(:put, "#{fhir_server_url}/Practitioner/practitioner1").to_return(status: 201)

    allow(task_status).to receive(:update_status)
  end

  describe '#perform' do
    it 'fetches each resource from its URL' do
      service.perform
      expect(WebMock).to have_requested(:get, 'http://example.com/resources/Patient/patient1').once
      expect(WebMock).to have_requested(:get, 'http://example.com/resources/Practitioner/practitioner1').once
    end

    it 'pushes each resource to the FHIR server via PUT' do
      service.perform
      expect(WebMock).to have_requested(:put, "#{fhir_server_url}/Practitioner/practitioner1")
        .with(body: practitioner_resource).once
      expect(WebMock).to have_requested(:put, "#{fhir_server_url}/Patient/patient1")
        .with(body: patient_resource).once
    end

    it 'updates task status with progress and completion in order' do
      # Order: start, push practitioner, push patient, complete
      expect(task_status).to receive(:update_status).with('running', a_string_starting_with('[0%] Starting data push...'))
      expect(task_status).to receive(:update_status).with('running', a_string_matching(%r{\[0%\].*Practitioner/practitioner1}))
      expect(task_status).to receive(:update_status).with('running', a_string_matching(%r{\[50%\].*Patient/patient1}))
      expect(task_status).to receive(:update_status).with('completed', '[100%] Push completed successfully. 2 resources pushed.')

      service.perform
    end

    context 'when a resource push fails initially' do
      before do
        stub_request(:put, "#{fhir_server_url}/Patient/patient1")
          .to_return({ status: 500, body: 'Internal Server Error' }, { status: 200 })
      end

      it 'retries the push and succeeds' do
        service.perform
        expect(WebMock).to have_requested(:put, "#{fhir_server_url}/Patient/patient1").twice
        expect(task_status).to have_received(:update_status).with('completed', '[100%] Push completed successfully. 2 resources pushed.')
      end
    end

    context 'when a resource push fails permanently' do
      before do
        stub_request(:put, "#{fhir_server_url}/Patient/patient1").to_return(status: 500, body: 'Internal Server Error')
      end

      it 'retries up to MAX_RETRIES times' do
        service.perform
        expect(WebMock).to have_requested(:put, "#{fhir_server_url}/Patient/patient1").times(FhirPushService::MAX_RETRIES)
      end

      it 'updates task status to failed with an error summary' do
        expect(task_status).to receive(:update_status).with('failed', a_string_matching(/Push completed with 1 failures.*HTTP Error 500/m))
        service.perform
      end
    end

    context 'when a resource is not a valid FHIR resource' do
      let(:invalid_resource) { { not_a_resource: true }.to_json }

      before do
        stub_request(:get, 'http://example.com/resources/Patient/patient1').to_return(body: invalid_resource)
      end

      it 'marks the task as failed' do
        expect(task_status).to receive(:update_status).with('failed', a_string_matching(/Push completed with 1 failures.*Invalid FHIR resource format/m))
        service.perform
      end
    end

    context 'when the server returns an OperationOutcome' do
      let(:operation_outcome) do
        {
          resourceType: 'OperationOutcome',
          issue: [{ severity: 'error', code: 'processing', details: { text: 'Invalid reference' } }]
        }.to_json
      end

      before do
        stub_request(:put, "#{fhir_server_url}/Patient/patient1")
          .to_return(status: 400, body: operation_outcome, headers: { 'Content-Type' => 'application/json' })
      end

      it 'updates task status with details from the OperationOutcome' do
        expect(task_status).to receive(:update_status).with('failed', a_string_matching(/error \(processing\): Invalid reference/))
        service.perform
      end
    end
  end
end
