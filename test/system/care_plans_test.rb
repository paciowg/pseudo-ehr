require "application_system_test_case"

class CarePlansTest < ApplicationSystemTestCase
  # setup do
  #   @care_plan = care_plans(:one)
  # end

  test "visiting the index" do
    visit care_plans_url
    assert_selector "h1", text: "Care Plans"
  end

  test "showing a Care Plan" do
    visit care_plans_url
    click_on "Show", match: :first
    assert page.has_content?("Conditions")
  end

  test "creating a Care plan" do
    visit care_plans_url
    click_on "New Care Plan"

    click_on "Create Care plan"

    assert_text "Care plan was successfully created"
    click_on "Back"
  end

  test "updating a Care plan" do
    visit care_plans_url
    click_on "Edit", match: :first

    click_on "Update Care plan"

    assert_text "Care plan was successfully updated"
    click_on "Back"
  end

  test "destroying a Care plan" do
    visit care_plans_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Care plan was successfully destroyed"
  end
end