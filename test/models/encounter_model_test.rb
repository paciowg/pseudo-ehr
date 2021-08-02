require 'test_helper'

class EncounterTest < ActiveSupport::TestCase
    file = File.read('data/Encounter-Encounter-1-SNF-Stay.json')
    let(:fhir_encounter) { FHIR.from_contents(file) }
    let(:client) { FHIR::Client.new('https://api.interop.community/PacioSandbox/open/')}
    let(:encounter) { described_class.new(fhir_encounter, client) }

    describe "#initialize" do
        it 'creates an Encounter instance from a fhir resource' do
            _(fhir_encounter).must_be_instance_of FHIR::Encounter
            _(encounter).must_be_instance_of Encounter 
        end

        it 'does not create an Encounter instance if arguments nil' do
            _(Encounter.new(nil, nil)).must_be_instance_of NilClass
        end
    end
    
    describe "#reassessment_timepoints" do
        it 'includes an id for encounter instance' do
            _(encounter.id).must_be :present?
        end

        it 'returns an array of 0 or more timepoints' do
            _(encounter.reassessment_timepoints).must_be_instance_of Array
        end
    end

    describe "#providers" do
        it 'includes a participant field for encounter instance that is an array' do
            _(encounter.participant).must_be_instance_of Array
        end

        it 'returns an array of 0 or more providers' do
            _(encounter.providers).must_be_instance_of Array
        end
    end
    
    describe "#diagnoses" do
        it 'includes a conditions field for encounter instance that is an array' do
            _(encounter.conditions).must_be_instance_of Array
        end

        it 'include a reference field for each item of conditions array' do
            outcome = encounter.conditions.all? { |item| item.condition.reference.present? }
        end

        it 'returns an array of 0 or more diagnoses' do
            _(encounter.diagnoses).must_be_instance_of Array
        end
    end
    
end