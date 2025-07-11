# spec/controllers/patients_controller_spec.rb
require 'rails_helper'

RSpec.describe PatientsController do
  let(:fhir_server) { create(:fhir_server, base_url: 'https://qa-rr-fhir2.maxmddirect.com', authenticated_access: false) }
  let(:client) { FhirClientService.new(fhir_server:).client }
  let(:patients_bundle) { FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::Patient.new(id: '123'))]) }
  let(:patient_id) { patients_bundle.entry.first.resource.id }

  before do
    session[:fhir_server_url] = fhir_server.base_url
    allow(Rails.cache).to receive(:fetch).and_call_original

    # Stub the FHIR server capability statement response
    stub_request(:get, "#{fhir_server.base_url}/metadata")
      .to_return(
        status: 200,
        body: FHIR::CapabilityStatement.new.to_json,
        headers: { 'Content-Type' => 'application/fhir+json' }
      )

    # Stub the FHIR server patient feed (used in index and show)
    stub_request(:get, "#{fhir_server.base_url}/Patient")
      .to_return(
        status: 200,
        body: patients_bundle.to_json,
        headers: { 'Content-Type' => 'application/fhir+json' }
      )

    # Stub the FHIR server single patient fetch (used in show)
    stub_request(:get, "#{fhir_server.base_url}/Patient/123")
      .to_return(
        status: 200,
        body: FHIR::Patient.new(id: '123').to_json,
        headers: { 'Content-Type' => 'application/fhir+json' }
      )

    # Stub the $everything operation
    stub_request(:get, "#{fhir_server.base_url}/Patient/123/$everything?_count=250&_maxresults=500&_sort=-_lastUpdated")
      .to_return(
        status: 200,
        body: FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::Observation.new(id: 'obs1'))]).to_json,
        headers: { 'Content-Type' => 'application/fhir+json' }
      )

    # Stub PractitionerRole search
    body = FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::PractitionerRole.new(id: 'role1'))]).to_json
    stub_request(:get, "#{fhir_server.base_url}/PractitionerRole?_count=150&_include=*&_sort=-_lastUpdated")
      .to_return(
        status: 200,
        body:,
        headers: { 'Content-Type' => 'application/fhir+json' }
      )
  end

  describe 'GET #index' do
    context 'when patients are successfully fetched' do
      before do
        get :index
      end

      it 'renders index without flash message' do
        expect(flash[:danger]).to be_nil
        expect(response).to render_template(:index)
      end
    end

    context 'when there is an error fetching patients' do
      before do
        allow(Patient).to receive(:all).and_return([])
        allow(Patient).to receive(:updated_at).and_return(nil)
        # Stub the FHIR server request to return an error for this case
        stub_request(:get, "#{fhir_server.base_url}/Patient?_count=250&_sort=-_lastUpdated&active=true")
          .to_return(
            status: 500,
            body: { issue: [{ diagnostics: 'Error fetching patients' }] }.to_json,
            headers: { 'Content-Type' => 'application/fhir+json' }
          )

        get :index
      end

      it 'sets the danger flash and still renders index' do
        expect(flash[:danger]).to match(/Error fetching or parsing patients from FHIR server/)
        expect(response).to render_template(:index)
      end
    end
  end

  describe 'GET #show' do
    context 'when patient is successfully fetched' do
      before do
        params = '_count=1000&_include=*&_include:iterate=*&_maxresults=2000&_revinclude=*&_sort=-_lastUpdated'
        url = "#{fhir_server.base_url}/Patient/123/$everything?#{params}"
        # Stub the FHIR server fetch patient record response
        stub_request(:get, url)
          .to_return(
            status: 200,
            body: FHIR::Bundle.new(entry: [FHIR::Bundle::Entry.new(resource: FHIR::Patient.new(id: patient_id))])
            .to_json,
            headers: { 'Content-Type' => 'application/fhir+json' }
          )
        # allow(controller).to receive(:retrieve_current_patient_resources).and_return([])
        get :show, params: { id: patient_id }
      end

      it 'sets session and renders show' do
        expect(session[:patient_id]).to eq(patient_id)
        expect(response).to render_template(:show)
      end
    end

    context 'when there is an error fetching the patient' do
      before do
        # Stub the request to return a 404 error for a non-existent patient
        stub_request(:get, "#{fhir_server.base_url}/Patient/dummy")
          .to_return(
            status: 404,
            body: { issue: [{ diagnostics: 'Patient not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/fhir+json' }
          )

        get :show, params: { id: 'dummy' }
      end

      it 'sets the danger flash and redirects to index' do
        expect(flash[:danger]).to eq('Error fetching or parsing patient from FHIR server. Check logs.')
        expect(response).to redirect_to patients_path
      end
    end
  end
end
