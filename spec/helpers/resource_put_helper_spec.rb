require 'rails_helper'

RSpec.describe ResourcePutHelper, type: :helper do
  let(:fhir_server) { create(:fhir_server) }
  let(:fhir_client_service) { FhirClientService.new(fhir_server:) }

  before do
    # Stub the FHIR server capability statement response
    stub_request(:get, "#{fhir_server.base_url}/metadata")
      .to_return(
        status: 200,
        body: FHIR::CapabilityStatement.new.to_json,
        headers: { 'Content-Type' => 'application/fhir+json' }
      )

    allow(helper).to receive(:current_server).and_return(fhir_server)
    allow(helper).to receive(:client).and_return(fhir_client_service.client)
  end

  describe '#create_new_toc_resource' do
    it 'creates a single resource using put' do
      # Stub the FHIR server response
      stub_request(:put, "#{fhir_server.base_url}/Composition/123")
        .to_return(
          status: 200,
          body: FHIR::Composition.new(id: '123', status: 'final').to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      response = helper.create_new_toc_resource(FHIR::Composition.new(id: '123', status: 'final'), method: :put,
                                                                                                   id: '123')
      expect(response.resource).to be_a(FHIR::Composition)
    end

    # it 'fails to create if not supported method' do
    #   response = helper.create_new_toc_resource(FHIR::Composition.new(id: '123', status: 'final'), method: :get,
    #                                                                                                id: '123')
    #   expect(response.result).to eq('error')
    #   expect(response.result_message).to match(/Unsupported method/)
    # end

    # it 'fails if create response is not the expected type' do
    #   # Stub the FHIR server response
    #   stub_request(:put, "#{fhir_server.base_url}/Composition/123")
    #     .to_return(
    #       status: 200,
    #       body: FHIR::Observation.new.to_json, # incorrect type
    #       headers: { 'Content-Type' => 'application/fhir+json' }
    #     )

    #   expect(helper.create_new_toc_resource(FHIR::Composition.new(id: '123', status: 'final'), method: :put,
    #                                                                                            id: '123')).to_raise(StandardError)
    # end
  end
end
