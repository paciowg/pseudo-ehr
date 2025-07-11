require 'rails_helper'

RSpec.describe ResourceFetchHelper, type: :helper do
  let(:fhir_server) { create(:fhir_server) }
  let(:fhir_client_service) { FhirClientService.new(fhir_server:) }
  let(:resource_class) { FHIR::Patient }
  let(:bundle) { FHIR::Bundle.new }

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

  describe '#fetch_resource' do
    it 'fetches resources using search' do
      # Stub the FHIR server search response
      stub_request(:get, "#{fhir_server.base_url}/Patient?_id=123")
        .to_return(
          status: 200,
          body: FHIR::Bundle.new.to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      response = helper.fetch_resource(resource_class, method: :search, parameters: { _id: '123' })
      expect(response.resource).to be_a(FHIR::Bundle)
    end

    it 'fetches resources using read' do
      # Stub the FHIR server read response
      stub_request(:get, "#{fhir_server.base_url}/Patient/123")
        .to_return(
          status: 200,
          body: FHIR::Patient.new(id: '123').to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      response = helper.fetch_resource(resource_class, method: :read, id: '123')
      expect(response.resource).to be_a(FHIR::Patient)
    end
  end

  describe '#fetch_single_patient' do
    it 'fetches a single patient by id' do
      # Stub the FHIR server read response
      stub_request(:get, "#{fhir_server.base_url}/Patient/123")
        .to_return(
          status: 200,
          body: FHIR::Patient.new(id: '123').to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      patient = helper.fetch_single_patient('123')
      expect(patient).to be_a(FHIR::Patient)
    end
  end

  describe '#fetch_patients_by_id' do
    it 'fetches patients by ID' do
      stub_request(:get, "#{fhir_server.base_url}/Patient?_count=1&_id&_sort=-_lastUpdated")
        .to_return(
          status: 200,
          body: FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::Patient.new(id: '123'))]).to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      result = helper.fetch_patients_by_id
      expect(result.first).to be_a(FHIR::Patient)
    end
  end

  describe '#fetch_patients_by_name' do
    it 'fetches patients by name' do
      stub_request(:get, "#{fhir_server.base_url}/Patient?_count=10&_sort=-_lastUpdated&active=true&name=John")
        .to_return(
          status: 200,
          body: FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::Patient.new(id: '123'))]).to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      allow(params).to receive(:[]).with(:query_name).and_return('John')

      result = helper.fetch_patients_by_name
      expect(result.first).to be_a(FHIR::Patient)
    end
  end

  describe '#fetch_single_patient_record' do
    it 'fetches patient records and handles pagination' do
      params = '_count=1000&_include=*&_include:iterate=*&_maxresults=2000&_revinclude=*&_sort=-_lastUpdated'
      url = "#{fhir_server.base_url}/Patient/123/$everything?#{params}"
      # Stub the FHIR server fetch patient record response
      stub_request(:get, url)
        .to_return(
          status: 200,
          body: FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::Patient.new(id: '123'))]).to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      result = helper.fetch_single_patient_record('123')
      expect(result.first).to be_a(FHIR::Patient)
    end
  end

  describe '#fetch_resource_with_defaults' do
    it 'fetches a resource with default parameters' do
      body = FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::Organization.new(id: 'org123'))]).to_json
      # Stub the FHIR server organization search response
      stub_request(:get, "#{fhir_server.base_url}/Organization?_sort=-_lastUpdated&_count=150")
        .to_return(
          status: 200,
          body:,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      result = helper.fetch_resource_with_defaults(FHIR::Organization)
      expect(result.first).to be_a(FHIR::Organization)
    end
  end

  describe '#fetch_document_reference' do
    it 'fetches a document reference by ID' do
      # Stub the FHIR server document reference read response
      stub_request(:get, "#{fhir_server.base_url}/DocumentReference/doc123")
        .to_return(
          status: 200,
          body: FHIR::DocumentReference.new(id: 'doc123').to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      document_reference = helper.fetch_document_reference('doc123')
      expect(document_reference).to be_a(FHIR::DocumentReference)
    end
  end

  describe '#fetch_binary' do
    it 'fetches a binary resource by ID' do
      # Stub the FHIR server binary read response
      stub_request(:get, "#{fhir_server.base_url}/Binary/bin123")
        .to_return(
          status: 200,
          body: FHIR::Binary.new(id: 'bin123').to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )

      binary = helper.fetch_binary('bin123')
      expect(binary).to be_a(FHIR::Binary)
    end
  end

  describe '#fetch_bundle_entries' do
    it 'fetches entries from a bundle and handles pagination' do
      url = "#{fhir_server.base_url}/Patient/123/$everything?_sort=-_lastUpdated&_maxresults=500&_count=250"
      stub_request(:get, url)
        .to_return(
          status: 200,
          body: FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::Patient.new(id: '123'))]).to_json,
          headers: { 'Content-Type' => 'application/fhir+json' }
        )
      response = double(
        'Response',
        resource: FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::Patient.new(id: '123'))])
      )
      result = helper.fetch_bundle_entries(response)
      expect(result.first).to be_a(FHIR::Patient)
    end
  end
end
