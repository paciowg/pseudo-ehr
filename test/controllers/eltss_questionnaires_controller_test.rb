require 'test_helper'

class EltssQuestionnairesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @eltss_questionnaire = eltss_questionnaires(:one)
  end

  test "should get index" do
    get eltss_questionnaires_url
    assert_response :success
  end

  test "should get new" do
    get new_eltss_questionnaire_url
    assert_response :success
  end

  test "should create eltss_questionnaire" do
    assert_difference('EltssQuestionnaire.count') do
      post eltss_questionnaires_url, params: { eltss_questionnaire: {  } }
    end

    assert_redirected_to eltss_questionnaire_url(EltssQuestionnaire.last)
  end

  test "should show eltss_questionnaire" do
    get eltss_questionnaire_url(@eltss_questionnaire)
    assert_response :success
  end

  test "should get edit" do
    get edit_eltss_questionnaire_url(@eltss_questionnaire)
    assert_response :success
  end

  test "should update eltss_questionnaire" do
    patch eltss_questionnaire_url(@eltss_questionnaire), params: { eltss_questionnaire: {  } }
    assert_redirected_to eltss_questionnaire_url(@eltss_questionnaire)
  end

  test "should destroy eltss_questionnaire" do
    assert_difference('EltssQuestionnaire.count', -1) do
      delete eltss_questionnaire_url(@eltss_questionnaire)
    end

    assert_redirected_to eltss_questionnaires_url
  end
end
