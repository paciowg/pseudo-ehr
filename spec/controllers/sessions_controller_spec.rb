# frozen_string_literal: true

# spec/controllers/sessions_controller_spec.rb
require 'rails_helper'

RSpec.describe SessionsController do
  let!(:fhir_server) { create(:fhir_server, base_url: 'https://qa-rr-fhir2.maxmddirect.com', authenticated_access: false) }

  describe 'GET #new' do
    context 'when server is present' do
      before do
        session[:fhir_server_url] = fhir_server.base_url
        get :new
      end

      it 'sets flash notice and redirects to patients_path' do
        expect(flash[:notice]).to include('Client already connected')
        expect(response).to redirect_to patients_path
      end
    end

    context 'when server is not present' do
      before { get :new }

      it 'renders the new template' do
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'POST #launch_server' do
    context 'when server does not have authenticated access' do
      before do
        post :launch_server, params: { base_url: 'https://qa-rr-fhir2.maxmddirect.com', authenticated_access: false, name: 'Fhir Server' }
      end

      it 'redirects to patients_path' do
        expect(response).to redirect_to patients_path
      end
    end

    # Add test for when server have authenticated access.
    # Add test for if an exception is raised in launch_server
  end

  describe 'GET #login' do
    context 'when there is an authorization error' do
      before do
        session[:fhir_server_url] = fhir_server.base_url
        get :login, params: { error: 'some_error', error_description: 'description' }
      end

      it 'sets the danger flash and redirects to root' do
        expect(flash[:danger]).to eq('Authorization Failure: some_error - description')
        expect(response).to redirect_to root_path
      end
    end

    # Add tests for other contexts for login action handling successful authentication, and exceptions.
  end

  describe 'GET #disconnect_server' do
    before do
      session[:fhir_server_url] = fhir_server.base_url
      get :disconnect_server
    end

    it 'resets the session, sets flash, and redirects to root' do
      expect(session[:fhir_server_url]).to be_nil
      expect(flash[:success]).to eq('Successfully disconnected client from server')
      expect(response).to redirect_to root_path
    end
  end

  # Add tests for private methods.
end
