require 'test_helper'

class CarePlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    get home_url, params: { server_url: "https://api.interop.community/PacioSandbox/open/" }
    file = File.read('app/controllers/careplan1.json')
    fhir_care_plan = JSON.parse(file, object_class: OpenStruct) # Use OpenStruct to enable dot synthax
    @care_plan = CarePlan.new(fhir_care_plan, nil)
  end

  test "should get index" do
    get care_plans_url
    assert_response :success
  end

  test "should get new" do
    get new_care_plan_url
    assert_response :success
  end

  test "should create care_plan when valid care plan data provided" do
    post care_plans_url, params: { care_plan: { } }
    assert_redirected_to care_plan_url(@care_plan.id)
  end

  test "should show care_plan" do
    get care_plan_url(@care_plan.id)
    assert_response :success
  end

  test "should get edit" do
    get edit_care_plan_url(@care_plan.id)
    assert_response :success
  end

  test "should update care_plan" do
    patch care_plan_url(@care_plan.id), params: { care_plan: {  } }
    assert_response :success
    # assert_redirected_to care_plan_url(@care_plan.id)
  end

  test "should destroy care_plan" do
    delete care_plan_url(@care_plan.id)
    assert_redirected_to care_plans_url
  end
end
