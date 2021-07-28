require 'test_helper'

class EncounterControllerTest < ActionDispatch::IntegrationTest
    before do
        # mitre_server = 'http://34.226.8.102:8080/fhir/'
        get home_url, params: { server_url: 'http://hapi.fhir.org/baseR4/' }
    end
    
    file = File.read('data/Encounter-Encounter-1-SNF-Stay.json')
    let(:fhir_encounter) { FHIR.from_contents(file) }
    let(:client) { FHIR::Client.new('http://hapi.fhir.org/baseR4/')}
    let(:encounter) { Encounter.new(fhir_encounter, client) }

   describe "Index action" do

    it 'gets index with a given patient id' do
        get patient_encounters_path('patientBSJ1')
        assert_response :success
        assert_template :index
        assert_not_nil assigns(:encounters)
        assert_not_nil assigns(:patient)
    end

    it 'redirects to previous page if patient with given id not found' do
        get patient_encounters_path('aa')
        assert_redirected_to request.referer
        assert_equal "Patient does not exist.", flash[:error]
    end

   end

   describe "Show action" do

      it 'gets show with a valid encounter id' do
        get encounter_path(encounter.id)
        assert_response :success
        assert_template :show
        assert_not_nil assigns(:encounter)
        assert_not_nil assigns(:patient)
      end

      it 'redirects to previous page if invalid encounter id provided' do
          get encounter_path('aa')
          assert_redirected_to request.referer
          assert_equal "The requested encounter does not exist.", flash[:error]
      end
   end
   
   
    
end