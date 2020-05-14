require 'test_helper'

class EpisodeOfCaresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @episode_of_care = episode_of_cares(:one)
  end

  test "should get index" do
    get episode_of_cares_url
    assert_response :success
  end

  test "should get new" do
    get new_episode_of_care_url
    assert_response :success
  end

  test "should create episode_of_care" do
    assert_difference('EpisodeOfCare.count') do
      post episode_of_cares_url, params: { episode_of_care: {  } }
    end

    assert_redirected_to episode_of_care_url(EpisodeOfCare.last)
  end

  test "should show episode_of_care" do
    get episode_of_care_url(@episode_of_care)
    assert_response :success
  end

  test "should get edit" do
    get edit_episode_of_care_url(@episode_of_care)
    assert_response :success
  end

  test "should update episode_of_care" do
    patch episode_of_care_url(@episode_of_care), params: { episode_of_care: {  } }
    assert_redirected_to episode_of_care_url(@episode_of_care)
  end

  test "should destroy episode_of_care" do
    assert_difference('EpisodeOfCare.count', -1) do
      delete episode_of_care_url(@episode_of_care)
    end

    assert_redirected_to episode_of_cares_url
  end
end
