require 'test_helper'

class ReAssessmentTimepointsControllerTest < ActionDispatch::IntegrationTest
  before do
    # mitre_server = 'http://34.226.8.102:8080/fhir/'
    get home_url, params: { server_url: 'https://api.interop.community/PacioSandbox/open/' }
  end

  file = File.read('data/Encounter-MDS-Re-assessment-Timepoint-1.json')
  let(:fhir_timepoint) { FHIR.from_contents(file) }
  let(:client) { FHIR::Client.new('https://api.interop.community/PacioSandbox/open/')}
  let(:timepoint) { ReAssessmentTimepoint.new(fhir_timepoint, client) }

  describe "Adding a new reassessment timepoint" do
    it 'shows the form to add a new reassessment timepoint for an encounter' do
      get new_re_assessment_timepoint_path
      assert_response :success
      assert_template :new
    end

    it 'creates a new reassessment timepoint' do
      post re_assessment_timepoints_path, params: {  }
      assert_response :redirect
      follow_redirect!
      assert_response :success
      assert_template :show
    end
  end
  
  describe "Show action" do

    it 'gets show with a valid reassessment timepoint id' do
      get re_assessment_timepoint_path(timepoint.id)
      assert_response :success
      assert_template :show
      assert_not_nil assigns(:reassessment_timepoint)
      assert_not_nil assigns(:patient)
    end

    it 'redirects to previous page if invalid reassessment timepoint id provided' do
        get re_assessment_timepoint_path('aa')
        assert_redirected_to request.referer || root_path
        assert_equal "The requested encounter does not exist.", flash[:error]
    end
 end
end