require 'test_helper'

class QuestionnaireResponsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @questionnaire_response = questionnaire_responses(:one)
  end

  test "should get index" do
    get questionnaire_responses_url
    assert_response :success
  end

  test "should get new" do
    get new_questionnaire_response_url
    assert_response :success
  end

  test "should create questionnaire_response" do
    assert_difference('QuestionnaireResponse.count') do
      post questionnaire_responses_url, params: { questionnaire_response: {  } }
    end

    assert_redirected_to questionnaire_response_url(QuestionnaireResponse.last)
  end

  test "should show questionnaire_response" do
    get questionnaire_response_url(@questionnaire_response)
    assert_response :success
  end

  test "should get edit" do
    get edit_questionnaire_response_url(@questionnaire_response)
    assert_response :success
  end

  test "should update questionnaire_response" do
    patch questionnaire_response_url(@questionnaire_response), params: { questionnaire_response: {  } }
    assert_redirected_to questionnaire_response_url(@questionnaire_response)
  end

  test "should destroy questionnaire_response" do
    assert_difference('QuestionnaireResponse.count', -1) do
      delete questionnaire_response_url(@questionnaire_response)
    end

    assert_redirected_to questionnaire_responses_url
  end
end
