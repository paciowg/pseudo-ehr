require 'test_helper'

class ObservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @observation = observations(:one)
  end

  test "should get index" do
    get observations_url
    assert_response :success
  end

  test "should get new" do
    get new_observation_url
    assert_response :success
  end

  test "should create observation" do
    assert_difference('Observation.count') do
      post observations_url, params: { observation: {  } }
    end

    assert_redirected_to observation_url(Observation.last)
  end

  test "should show observation" do
    get observation_url(@observation)
    assert_response :success
  end

  test "should get edit" do
    get edit_observation_url(@observation)
    assert_response :success
  end

  test "should update observation" do
    patch observation_url(@observation), params: { observation: {  } }
    assert_redirected_to observation_url(@observation)
  end

  test "should destroy observation" do
    assert_difference('Observation.count', -1) do
      delete observation_url(@observation)
    end

    assert_redirected_to observations_url
  end
end
