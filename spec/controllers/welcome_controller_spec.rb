# frozen_string_literal: true

# spec/controllers/welcome_controller_spec.rb
require 'rails_helper'

RSpec.describe WelcomeController, type: :controller do
  describe 'GET #index' do
    context 'when server is present' do
      let!(:fhir_server) { create(:fhir_server, base_url: 'http://hapi.fhir.org/baseR4') }

      before do
        session[:fhir_server_url] = fhir_server.base_url
        get :index
      end

      it 'sets a flash notice' do
        expect(flash[:notice]).to eq("You are connected to FHIR Server: #{fhir_server.base_url}")
      end

      it 'redirects to pages_patients_path' do
        expect(response).to redirect_to pages_patients_path
      end
    end

    context 'when server is not present' do
      before do
        session[:fhir_server_url] = nil
        get :index
      end

      it 'does not set a flash notice' do
        expect(flash[:notice]).to be_nil
      end

      it 'renders the index view' do
        expect(response).to render_template(:index)
      end
    end
  end
end
