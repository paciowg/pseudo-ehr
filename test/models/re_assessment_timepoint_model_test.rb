require 'test_helper'

class ReAssessmentTimepointTest < ActiveSupport::TestCase
    file = File.read('data/Encounter-MDS-Re-assessment-Timepoint-1.json')
    let(:fhir_timepoint) { FHIR.from_contents(file) }
    let(:client) { FHIR::Client.new('https://api.interop.community/PacioSandbox/open/')}
    let(:timepoint) { described_class.new(fhir_timepoint, client) }

    describe "#initialize" do
        it 'creates a ReAssessmentTimepoint instance from a fhir resource' do
            _(fhir_timepoint).must_be_instance_of FHIR::Encounter
            _(timepoint).must_be_instance_of ReAssessmentTimepoint 
        end

        # it 'does not create a ReAssessmentTimepoint instance if arguments nil' do
        #     _(ReAssessmentTimepoint.new(nil, nil)).must_be_instance_of NilClass
        # end
    end
    
    describe "#assessments" do
        it 'must be a ReAssessmentTimepoint instance method' do
            _(timepoint).must_respond_to :assessments
        end

        it 'returns an array of 0 or more timepoints' do
            _(timepoint.assessments).must_be_instance_of Array
        end
    end

    describe "#providers" do
        it 'must be a ReAssessmentTimepoint instance method' do
            _(timepoint).must_respond_to :providers
        end
        it 'includes a participant field for ReAssessmentTimepoint instance that is an array' do
            _(timepoint.participant).must_be_instance_of Array
        end

        it 'returns an array of 1 or more providers' do
            _(timepoint.providers).must_be_instance_of Array
            _(timepoint.providers.size).must_be :>=, 1
        end
    end
    
    describe "#episodes_of_care" do
        it 'must be a ReAssessmentTimepoint instance method' do
            _(timepoint).must_respond_to :episodes_of_care
        end
        it 'returns an array of 0 or more episodes of care the timepoint instance is part of' do
            _(timepoint.episodes_of_care).must_be_instance_of Array
        end
    end

    describe "#locations" do
        it 'must be a ReAssessmentTimepoint instance method' do
            _(timepoint).must_respond_to :locations
        end
        it 'returns an array of 1 or more locations the timepoint took place' do
            _(timepoint.locations).must_be_instance_of Array
            _(timepoint.locations.size).must_be :>=, 1
        end
    end
end