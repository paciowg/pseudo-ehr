# spec/controllers/application_controller_spec.rb

require 'rails_helper'

RSpec.describe ApplicationController do
  let!(:fhir_server) { create(:fhir_server, base_url: 'https://qa-rr-fhir2.maxmddirect.com') }

  controller do
    before_action :require_server

    def index
      render plain: 'Hello, World!'
    end
  end

  before do
    # Stub the FHIR server capability statement response
    stub_request(:get, "#{fhir_server.base_url}/metadata")
      .to_return(
        status: 200,
        body: FHIR::CapabilityStatement.new.to_json,
        headers: { 'Content-Type' => 'application/fhir+json' }
      )
  end

  describe '#current_server' do
    it 'returns the FhirServer instance based on session' do
      session[:fhir_server_url] = 'https://qa-rr-fhir2.maxmddirect.com'
      expect(controller.current_server).to eq(fhir_server)
    end

    it 'returns nil if session does not have fhir_server_url' do
      expect(controller.current_server).to be_nil
    end
  end

  describe '#server_present?' do
    context 'when current_server returns an instance' do
      before { allow(controller).to receive(:current_server).and_return(true) }

      it 'returns true' do
        expect(controller).to be_server_present
      end
    end

    context 'when current_server returns nil' do
      before { allow(controller).to receive(:current_server).and_return(nil) }

      it 'returns false' do
        expect(controller).not_to be_server_present
      end
    end
  end

  describe '#require_server' do
    context 'when server is present' do
      it 'does not redirect' do
        session[:fhir_server_url] = 'https://qa-rr-fhir2.maxmddirect.com'
        get :index
        expect(response.body).to eq('Hello, World!')
      end
    end

    context 'when server is not present' do
      before { allow(controller).to receive(:current_server).and_return(nil) }

      it 'redirects to root path with a flash message' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:danger]).to eq('No session available. Please connect to a fhir server to get started')
      end
    end
  end

  describe '#set_client' do
    before { allow(controller).to receive(:current_server).and_return(fhir_server) }

    it 'sets the @client variable' do
      controller.set_client
      expect(assigns(:client)).to be_instance_of(FHIR::Client)
    end
  end
end
