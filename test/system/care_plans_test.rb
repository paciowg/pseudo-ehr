require "application_system_test_case"

class CarePlansTest < ApplicationSystemTestCase
  setup do
    # Provide a fhir server url and setup a session
    visit root_url
    fill_in("server_url", with: "http://hapi.fhir.org/baseR4/")
    click_on "Connect"
    
    file = File.read('app/controllers/careplan1.json')
    fhir_care_plan = FHIR.from_contents(file) 
    @care_plan = CarePlan.new(fhir_care_plan, nil)
   
  end

  test "visiting the index" do
    visit care_plans_url
    assert_selector "h1", text: "Care Plans"
  end

  test "showing a Care Plan" do
    visit care_plans_url
    if page.has_link?("Show")
      click_on "Show", match: :first
    else
      visit care_plan_url(@care_plan.id)
    end

    assert page.has_content?("Conditions")
  end

  test "creating a Care plan" do
    visit care_plans_url
    click_on "New Care Plan"

    click_on "Create Care plan"

    assert_content "Care plan was successfully created."
  end

  test "updating a Care plan" do
    visit care_plans_url
    if page.has_link?("Edit")
      click_on "Edit", match: :first
      click_on "Create Care plan"
    else
      patch care_plan_url(@care_plan.id), params: { care_plan: {  } }
    end 

    assert_content "Care plan was successfully created."
  end

  test "destroying a Care plan" do
    visit care_plans_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Care plan was successfully destroyed"
  end
end