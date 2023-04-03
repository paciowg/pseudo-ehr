require "test_helper"

class CapabilityStatementControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get capability_statement_index_url
    assert_response :success
  end
end
