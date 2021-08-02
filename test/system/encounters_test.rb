require "application_system_test_case"

class EncountersTest < ApplicationSystemTestCase

    before do
        # mitre_server = 'http://34.226.8.102:8080/fhir/'
        visit root_path
        fill_in("server_url", with: "https://api.interop.community/PacioSandbox/open/")
        click_on "Connect"

        fill_in("name", with: "smith-johnson")
        click_on "Search"
        
        click_on("patientBSJ1")
        
    end
    
    describe "Navigate to patient's Encounters index page" do

        it "Loads the patient's Encounters index page " do
            click_on "Encounters"
            current_path.must_equal(patient_encounters_path("patientBSJ1"))
            page.must_have_content("FHIR Queries")
            page.must_have_content("Encounters list")
            page.must_have_selector(:css, "a[href='/dashboard?patient=patientBSJ1']")
        end

    end
    
    describe "Encounter's show page" do
        
        it "Loads the encounter's show page" do
            
            within(:css, "#encounters-card") do
                click_on "View", match: :first
            end
            page.must_have_content("FHIR Queries")
            page.must_have_content("Encounter Details")
            page.find_link("Add Timepoint").wont_be_nil
        end
    end
    
end