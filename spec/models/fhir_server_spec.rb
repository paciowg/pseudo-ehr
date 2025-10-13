# rubocop:disable RSpec/NamedSubject
# spec/models/fhir_server_spec.rb

require 'rails_helper'

RSpec.describe FhirServer do
  describe 'validations' do
    subject { build(:fhir_server) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:base_url) }
    it { is_expected.to validate_presence_of(:base_url) }

    context 'when authenticated_access is true' do
      before { allow(subject).to receive(:authenticated_access?).and_return(true) }

      it { is_expected.to validate_presence_of(:client_id) }
      it { is_expected.to validate_presence_of(:client_secret) }
      it { is_expected.to validate_presence_of(:authorization_url) }
      it { is_expected.to validate_presence_of(:token_url) }
      it { is_expected.to validate_presence_of(:scope) }
    end

    context 'when authenticated_access is false or nil' do
      before { allow(subject).to receive(:authenticated_access?).and_return(false) }

      it { is_expected.not_to validate_presence_of(:client_id) }
      it { is_expected.not_to validate_presence_of(:client_secret) }
      it { is_expected.not_to validate_presence_of(:authorization_url) }
      it { is_expected.not_to validate_presence_of(:token_url) }
      it { is_expected.not_to validate_presence_of(:scope) }
    end
  end

  describe 'before_save callback' do
    let(:fhir_server) { build(:fhir_server, base_url: '  https://example.com/ ', name: ' Test ', client_id: ' CID ', client_secret: ' SEC ') }

    it 'cleans up the attributes' do
      fhir_server.save

      expect(fhir_server.base_url).to eq('https://example.com')
      expect(fhir_server.name).to eq('Test')
      expect(fhir_server.client_id).to eq('CID')
      expect(fhir_server.client_secret).to eq('SEC')
    end
  end

  describe 'ensure_client_credentials_present' do
    context 'when authenticated_access is true and client credentials are missing' do
      let(:fhir_server) { build(:fhir_server, client_id: nil, authenticated_access: true) }

      it 'adds error for authenticated_access' do
        fhir_server.valid?
        expect(fhir_server.errors[:authenticated_access]).to include('requires client_id, client_secret, token_url and scope to be present')
      end
    end

    context 'when authenticated_access is true and all client credentials are present' do
      let(:fhir_server) { build(:fhir_server, authenticated_access: true) }

      it 'does not add error for authenticated_access' do
        fhir_server.valid?
        expect(fhir_server.errors[:authenticated_access]).to be_empty
      end
    end
  end
end
# rubocop:enable RSpec/NamedSubject
