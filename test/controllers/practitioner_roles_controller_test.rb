require 'test_helper'

class PractitionerRolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @practitioner_role = practitioner_roles(:one)
  end

  test "should get index" do
    get practitioner_roles_url
    assert_response :success
  end

  test "should get new" do
    get new_practitioner_role_url
    assert_response :success
  end

  test "should create practitioner_role" do
    assert_difference('PractitionerRole.count') do
      post practitioner_roles_url, params: { practitioner_role: {  } }
    end

    assert_redirected_to practitioner_role_url(PractitionerRole.last)
  end

  test "should show practitioner_role" do
    get practitioner_role_url(@practitioner_role)
    assert_response :success
  end

  test "should get edit" do
    get edit_practitioner_role_url(@practitioner_role)
    assert_response :success
  end

  test "should update practitioner_role" do
    patch practitioner_role_url(@practitioner_role), params: { practitioner_role: {  } }
    assert_redirected_to practitioner_role_url(@practitioner_role)
  end

  test "should destroy practitioner_role" do
    assert_difference('PractitionerRole.count', -1) do
      delete practitioner_role_url(@practitioner_role)
    end

    assert_redirected_to practitioner_roles_url
  end
end
