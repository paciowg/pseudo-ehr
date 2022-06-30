require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase

    test "visiting the index" do
        visit root_url
        fill_in("server_url", with: "http://hapi.fhir.org/baseR4/")
        click_on "Connect"
        assert_selector "h2", text: "Patients"
        
        assert_changes "all('button').count" do
            name = all("button").first.text
            find("input").set(name)
        end
    end
end