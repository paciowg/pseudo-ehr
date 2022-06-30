require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index without any given params" do
    get dashboard_url
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "should get index with patient params" do
    # setup a session here
    get dashboard_url, params: {patient: 1}
    assert_response :success
  end

end
