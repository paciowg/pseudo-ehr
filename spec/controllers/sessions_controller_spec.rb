require 'rails_helper'

RSpec.describe SessionsController do
  let(:fhir_server) { create(:fhir_server, base_url: 'https://qa-rr-fhir2.maxmddirect.com', authenticated_access: false) }

  before do
    # Stub the FHIR server metadata (CapabilityStatement) request
    stub_request(:get, "#{fhir_server.base_url}/metadata")
      .to_return(
        status: 200,
        body: FHIR::CapabilityStatement.new.to_json,
        headers: { 'Content-Type' => 'application/fhir+json' }
      )
  end

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
        post :launch_server,
             params: { base_url: fhir_server.base_url, authenticated_access: false, name: 'Fhir Server' }
      end

      it 'redirects to patients_path' do
        expect(response).to redirect_to patients_path
      end
    end

    context 'when server has authenticated access' do
      let(:fhir_server) { create(:fhir_server, base_url: 'https://qa-rr-fhir2.maxmddirect.com', authenticated_access: true) }

      before do
        stub_request(:get, "#{fhir_server.base_url}/metadata")
          .to_return(
            status: 200,
            body: FHIR::CapabilityStatement.new.to_json,
            headers: { 'Content-Type' => 'application/fhir+json' }
          )
        post :launch_server, params: { base_url: fhir_server.base_url, authenticated_access: true, name: 'Fhir Server' }
      end

      it 'redirects to the authorization URL' do
        expect(response).to redirect_to(/response_type=code/)
      end
    end

    context 'when an error occurs during server connection' do
      before do
        allow(FhirClientService).to receive(:new).and_raise(StandardError, 'Connection Error')
        post :launch_server,
             params: { base_url: fhir_server.base_url, authenticated_access: false, name: 'Fhir Server' }
      end

      it 'sets the danger flash and redirects to root_path' do
        expect(flash[:danger]).to eq('Connection Error')
        expect(response).to redirect_to root_path
      end
    end
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

    context 'when authentication is successful' do
      before do
        session[:fhir_server_url] = fhir_server.base_url
        session[:code_verifier] = 'test_code_verifier'

        get :login, params: { code: 'test_auth_code' }
      end

      it 'creates a FhirClientService instance and sets the success flash' do
        expect(flash[:success]).to eq('Successfully authenticated with server.')
      end

      it 'redirects to the patients path' do
        expect(response).to redirect_to patients_path
      end
    end

    context 'when an exception occurs during login' do
      before do
        session[:fhir_server_url] = fhir_server.base_url
        allow(FhirClientService).to receive(:new).and_raise(StandardError, 'Connection Error')
        get :login, params: { code: 'test_auth_code' }
      end

      it 'sets the danger flash and redirects to root' do
        expect(flash[:danger]).to match(/Internal Error after authorization/)
        expect(response).to redirect_to root_path
      end
    end
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

    context 'when server has authenticated access' do
      let(:fhir_server) do
        create(:fhir_server, base_url: 'https://qa-rr-fhir2.maxmddirect.com',
                             authenticated_access: true,
                             access_token: 'example-access-token',
                             refresh_token: 'example-refresh-token',
                             access_token_expires_at: 'example-access-token-date')
      end

      before do
        session[:fhir_server_url] = fhir_server.base_url
        get :disconnect_server
      end

      it 'deletes the access_token, refresh_token, and access_token_expires_at fields from an authenticated server' do
        expect(session[:fhir_server_url]).to be_nil
        expect(session[:access_token]).to be_nil
        expect(session[:refresh_token]).to be_nil
        expect(session[:access_token_expires_at]).to be_nil
        expect(flash[:success]).to eq('Successfully disconnected client from server')
        expect(response).to redirect_to root_path
      end
    end
  end
end
