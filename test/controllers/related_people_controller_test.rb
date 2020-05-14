require 'test_helper'

class RelatedPeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @related_person = related_people(:one)
  end

  test "should get index" do
    get related_people_url
    assert_response :success
  end

  test "should get new" do
    get new_related_person_url
    assert_response :success
  end

  test "should create related_person" do
    assert_difference('RelatedPerson.count') do
      post related_people_url, params: { related_person: {  } }
    end

    assert_redirected_to related_person_url(RelatedPerson.last)
  end

  test "should show related_person" do
    get related_person_url(@related_person)
    assert_response :success
  end

  test "should get edit" do
    get edit_related_person_url(@related_person)
    assert_response :success
  end

  test "should update related_person" do
    patch related_person_url(@related_person), params: { related_person: {  } }
    assert_redirected_to related_person_url(@related_person)
  end

  test "should destroy related_person" do
    assert_difference('RelatedPerson.count', -1) do
      delete related_person_url(@related_person)
    end

    assert_redirected_to related_people_url
  end
end
