require 'test_helper'

class RiskAssessmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @risk_assessment = risk_assessments(:one)
  end

  test "should get index" do
    get risk_assessments_url
    assert_response :success
  end

  test "should get new" do
    get new_risk_assessment_url
    assert_response :success
  end

  test "should create risk_assessment" do
    assert_difference('RiskAssessment.count') do
      post risk_assessments_url, params: { risk_assessment: {  } }
    end

    assert_redirected_to risk_assessment_url(RiskAssessment.last)
  end

  test "should show risk_assessment" do
    get risk_assessment_url(@risk_assessment)
    assert_response :success
  end

  test "should get edit" do
    get edit_risk_assessment_url(@risk_assessment)
    assert_response :success
  end

  test "should update risk_assessment" do
    patch risk_assessment_url(@risk_assessment), params: { risk_assessment: {  } }
    assert_redirected_to risk_assessment_url(@risk_assessment)
  end

  test "should destroy risk_assessment" do
    assert_difference('RiskAssessment.count', -1) do
      delete risk_assessment_url(@risk_assessment)
    end

    assert_redirected_to risk_assessments_url
  end
end
