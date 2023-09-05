# frozen_string_literal: true

# spec/controllers/patients_controller_spec.rb
require 'rails_helper'

RSpec.describe PatientsController, type: :controller do
  let!(:fhir_server) { create(:fhir_server, base_url: 'http://hapi.fhir.org/baseR4', authenticated_access: false) }
  let!(:client) { FhirClientService.new(fhir_server: fhir_server).client }
  let!(:patients) { client.read_feed(FHIR::Patient).resource.entry.map(&:resource) }
  let!(:patient_id) { patients.first.id }

  before do
    session[:fhir_server_url] = fhir_server.base_url
    allow(Rails.cache).to receive(:fetch).and_call_original
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
        server = create(:fhir_server, base_url: 'http://example.com', authenticated_access: false)
        session[:fhir_server_url] = server.base_url
        get :index
      end

      it 'sets the danger flash and still renders index' do
        expect(flash[:danger]).to eq('Error fetching patients from FHIR server. Status code: 404')
        expect(response).to render_template(:index)
      end
    end
  end

  describe 'GET #show' do
    context 'when patient is successfully fetched' do
      before do
        get :show, params: { id: patient_id }
      end

      it 'sets session and renders show' do
        expect(session[:patient_id]).to eq(patient_id)
        expect(response).to render_template(:show)
      end
    end

    context 'when there is an error fetching the patient' do
      before do
        get :show, params: { id: 'dummy' }
      end

      it 'sets the danger flash and redirects to index' do
        expect(flash[:danger]).to eq('Unable to fetch patient with id dummy from FHIR server.')
        expect(response).to redirect_to pages_patients_path
      end
    end
  end
end
