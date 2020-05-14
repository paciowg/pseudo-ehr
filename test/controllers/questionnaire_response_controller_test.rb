require 'test_helper'

class QuestionnaireResponseControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get questionnaire_response_index_url
    assert_response :success
  end

  test "should get show" do
    get questionnaire_response_show_url
    assert_response :success
  end

end
