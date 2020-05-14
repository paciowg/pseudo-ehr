require 'test_helper'

class ObservationEltssesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @observation_eltss = observation_eltsses(:one)
  end

  test "should get index" do
    get observation_eltsses_url
    assert_response :success
  end

  test "should get new" do
    get new_observation_eltss_url
    assert_response :success
  end

  test "should create observation_eltss" do
    assert_difference('ObservationEltss.count') do
      post observation_eltsses_url, params: { observation_eltss: {  } }
    end

    assert_redirected_to observation_eltss_url(ObservationEltss.last)
  end

  test "should show observation_eltss" do
    get observation_eltss_url(@observation_eltss)
    assert_response :success
  end

  test "should get edit" do
    get edit_observation_eltss_url(@observation_eltss)
    assert_response :success
  end

  test "should update observation_eltss" do
    patch observation_eltss_url(@observation_eltss), params: { observation_eltss: {  } }
    assert_redirected_to observation_eltss_url(@observation_eltss)
  end

  test "should destroy observation_eltss" do
    assert_difference('ObservationEltss.count', -1) do
      delete observation_eltss_url(@observation_eltss)
    end

    assert_redirected_to observation_eltsses_url
  end
end
