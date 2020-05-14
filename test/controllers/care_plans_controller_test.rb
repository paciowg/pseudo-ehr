require 'test_helper'

class CarePlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @care_plan = care_plans(:one)
  end

  test "should get index" do
    get care_plans_url
    assert_response :success
  end

  test "should get new" do
    get new_care_plan_url
    assert_response :success
  end

  test "should create care_plan" do
    assert_difference('CarePlan.count') do
      post care_plans_url, params: { care_plan: {  } }
    end

    assert_redirected_to care_plan_url(CarePlan.last)
  end

  test "should show care_plan" do
    get care_plan_url(@care_plan)
    assert_response :success
  end

  test "should get edit" do
    get edit_care_plan_url(@care_plan)
    assert_response :success
  end

  test "should update care_plan" do
    patch care_plan_url(@care_plan), params: { care_plan: {  } }
    assert_redirected_to care_plan_url(@care_plan)
  end

  test "should destroy care_plan" do
    assert_difference('CarePlan.count', -1) do
      delete care_plan_url(@care_plan)
    end

    assert_redirected_to care_plans_url
  end
end
