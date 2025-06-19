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
      before { allow(controller).to receive(:current_server).and_return(fhir_server) }

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

      it 'resets session and redirects to root path with a flash message' do
        allow(controller).to receive(:reset_session)
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

  describe '#retrieve_patient' do
    let(:patient_id) { '123' }

    context 'when no error' do
      before do
        allow(controller).to receive(:patient_id).and_return(patient_id)
        allow(controller).to receive(:fetch_single_patient).with(patient_id).and_return(FHIR::Patient.new(id: patient_id))
        allow(Rails.cache).to receive(:fetch).and_yield
      end

      it 'sets the @patient variable' do
        controller.retrieve_patient
        expect(assigns(:patient)).to be_instance_of(Patient)
        expect(assigns(:patient).id).to eq(patient_id)
      end
    end

    context 'when an error occurs while fetching patient' do
      before do
        allow(controller).to receive(:fetch_single_patient).and_raise(StandardError, 'Some error')
        allow(Rails.logger).to receive(:error)
        allow(controller).to receive(:redirect_to)
      end

      it 'logs the error and does not set @patient' do
        controller.retrieve_patient
        expect(assigns(:patient)).to be_nil
        expect(Rails.logger).to have_received(:error).with(/Error fetching patient: Some error/)
      end
    end
  end

  describe '#retrieve_practitioner_roles' do
    let(:patient_id) { '123' }

    context 'when no error' do
      before do
        allow(controller).to receive(:patient_id).and_return(patient_id)
        allow(controller).to receive(:fetch_practitioner_roles).and_return([FHIR::PractitionerRole.new])
      end

      it 'sets @practitioner_roles' do
        roles = controller.retrieve_practitioner_roles
        expect(roles).to all(be_instance_of(FHIR::PractitionerRole))
      end
    end

    context 'when an error occurs while fetching practitioner roles' do
      before do
        allow(PractitionerRoleCache).to receive(:expired?).and_return(true)
        allow(controller).to receive(:fetch_practitioner_roles).and_raise(StandardError, 'Some error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and returns an empty array' do
        roles = controller.retrieve_practitioner_roles
        expect(roles).to eq([])
        expect(Rails.logger).to have_received(:error).with(/Empty bundle or Error fetching practitioner roles/)
      end
    end
  end

  describe '#set_resources_count' do
    let(:patient_id) { '123' }

    before do
      allow(controller).to receive(:patient_id).and_return(patient_id)
      allow(controller).to receive(:cached_resources_type).with(anything).and_return([])
    end

    it 'sets resource count variables' do
      controller.set_resources_count
      expect(assigns(:care_team_count)).to eq(0)
      expect(assigns(:condition_count)).to eq(0)
      expect(assigns(:goal_count)).to eq(0)
      expect(assigns(:medication_list_count)).to eq(0)
      expect(assigns(:observation_count)).to eq(0)
      expect(assigns(:questionnaire_response_count)).to eq(0)
      expect(assigns(:nutrition_order_count)).to eq(0)
      expect(assigns(:service_request_count)).to eq(0)
      expect(assigns(:adi_count)).to eq(0)
      expect(assigns(:toc_count)).to eq(0)
    end
  end
end
