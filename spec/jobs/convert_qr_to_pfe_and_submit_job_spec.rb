require 'rails_helper'

RSpec.describe ConvertQrToPfeAndSubmitJob, type: :job do
  subject(:qr_conversion_job) { described_class.new }

  let(:qr_hash) { { 'resourceType' => 'QuestionnaireResponse', 'id' => '123' } }
  let(:fhir_server_url) { 'http://example.com/fhir' }
  let(:task_id) { 'task-123' }
  let(:patient_id) { 'patient-123' }
  let(:task_status) { instance_double(TaskStatus) }
  let(:api_url) { 'http://test.host/api/convert_qr_to_pfe_and_submit' }
  let(:host) { 'test.host' }

  before do
    allow(TaskStatus).to receive(:find_by).with(task_id: task_id).and_return(task_status)
    allow(task_status).to receive(:mark_running)
    allow(task_status).to receive(:mark_completed)
    allow(task_status).to receive(:mark_failed)

    allow(Rails.application.routes.url_helpers)
      .to receive(:api_convert_qr_to_pfe_and_submit_url)
      .with(any_args).and_return(api_url)
  end

  describe '#perform' do
    context 'when task is not found' do
      before do
        allow(TaskStatus).to receive(:find_by).with(task_id: task_id).and_return(nil)
        allow(Faraday).to receive(:post)
      end

      it 'returns early and does not process the job' do
        qr_conversion_job.perform(qr_hash, fhir_server_url, task_id, patient_id)

        expect(Faraday).not_to have_received(:post)
      end
    end

    context 'when conversion is successful' do
      let(:successful_response) do
        instance_double(
          Faraday::Response,
          success?: true,
          body: {
            'resource' => {
              'resourceType' => 'Bundle',
              'entry' => [
                {
                  'resource' => {
                    'resourceType' => 'Observation',
                    'id' => 'obs-1'
                  }
                }
              ]
            }
          }.to_json
        )
      end

      let(:fhir_bundle) do
        bundle = FHIR::Bundle.new
        entry = FHIR::Bundle::Entry.new
        obs = FHIR::Observation.new
        obs.id = 'obs-1'
        entry.resource = obs
        bundle.entry = [entry]
        bundle
      end

      let(:patient_record) { double('PatientRecord') }

      before do
        allow(Faraday).to receive(:post).and_yield(req = double).and_return(successful_response)
        allow(req).to receive(:headers).and_return({})
        allow(req).to receive(:body=)

        allow(FHIR).to receive(:from_contents).and_return(fhir_bundle)
        allow(PatientRecordCache).to receive(:update_patient_record)
        allow(PatientRecordCache).to receive(:get_patient_record).and_return(patient_record)
        allow(Observation).to receive(:new)
      end

      it 'processes the job successfully' do
        qr_conversion_job.perform(qr_hash, fhir_server_url, task_id, patient_id)

        expect(task_status).to have_received(:mark_running)
          .with("Task #{task_id}: Converting QuestionnaireResponse to PFE Observations...")
        expect(Faraday).to have_received(:post).with(api_url)
        expect(PatientRecordCache).to have_received(:update_patient_record).with(patient_id,
                                                                                 [fhir_bundle.entry.first.resource])
        expect(Observation).to have_received(:new).with(fhir_bundle.entry.first.resource, patient_record)
        expect(task_status).to have_received(:mark_completed)
          .with("Task #{task_id}: Conversion completed successfully.")
      end
    end

    context 'when conversion fails with API error' do
      let(:failed_response) do
        instance_double(
          Faraday::Response,
          success?: false,
          status: 400,
          body: { 'error' => 'Invalid QuestionnaireResponse format' }.to_json
        )
      end

      before do
        allow(Faraday).to receive(:post).and_yield(req = double).and_return(failed_response)
        allow(req).to receive(:headers).and_return({})
        allow(req).to receive(:body=)
        allow(PatientRecordCache).to receive(:update_patient_record)
      end

      it 'marks the task as failed with the error message' do
        qr_conversion_job.perform(qr_hash, fhir_server_url, task_id, patient_id)

        expect(task_status).to have_received(:mark_running)
        expect(task_status).to have_received(:mark_failed)
          .with("Task #{task_id}: Conversion failed: Invalid QuestionnaireResponse format")
        expect(PatientRecordCache).not_to have_received(:update_patient_record)
      end
    end

    context 'when conversion fails without parseable error' do
      let(:failed_response) do
        instance_double(
          Faraday::Response,
          success?: false,
          status: 500,
          body: 'Internal Server Error'
        )
      end

      before do
        allow(Faraday).to receive(:post).and_yield(req = double).and_return(failed_response)
        allow(req).to receive(:headers).and_return({})
        allow(req).to receive(:body=)
        allow(PatientRecordCache).to receive(:update_patient_record)
      end

      it 'marks the task as failed with the status code' do
        qr_conversion_job.perform(qr_hash, fhir_server_url, task_id, patient_id)

        expect(task_status).to have_received(:mark_running)
        expect(task_status).to have_received(:mark_failed).with("Task #{task_id}: Conversion failed: 500")
        expect(PatientRecordCache).not_to have_received(:update_patient_record)
      end
    end

    context 'when an unexpected exception occurs' do
      before do
        allow(Faraday).to receive(:post).and_raise(StandardError.new('Connection error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and marks the task as failed' do
        qr_conversion_job.perform(qr_hash, fhir_server_url, task_id, patient_id)

        expect(task_status).to have_received(:mark_running)
        expect(task_status).to have_received(:mark_failed).with('Unexpected error: Connection error')
        expect(Rails.logger).to have_received(:error).with('[QR Conversion Job] Connection error')
      end
    end
  end
end
