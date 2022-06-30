require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get home_url, params: { server_url: "http://hapi.fhir.org/baseR4/" }
    assert_response :success
  end

end
