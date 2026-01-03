# frozen_string_literal: true

require "test_helper"

class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:acme)
  end

  # Authentication
  test "returns unauthorized without token" do
    get api_v1_alerts_url
    assert_response :unauthorized

    json = JSON.parse(response.body)
    assert_equal "Unauthorized", json["error"]
  end

  test "returns unauthorized with empty token" do
    get api_v1_alerts_url, headers: { "Authorization" => "Bearer " }
    assert_response :unauthorized
  end

  test "returns unauthorized without project_id" do
    get api_v1_alerts_url, headers: { "Authorization" => "Bearer valid_token" }
    assert_response :unauthorized
  end

  test "accepts valid token with project_id in header" do
    get api_v1_alerts_url, headers: {
      "Authorization" => "Bearer valid_token",
      "X-Project-ID" => @project.id
    }
    assert_response :success
  end

  test "accepts valid token with project_id in params" do
    get api_v1_alerts_url(project_id: @project.id), headers: {
      "Authorization" => "Bearer valid_token"
    }
    assert_response :success
  end

  # JSON response format
  test "returns JSON content type" do
    get api_v1_alerts_url, headers: auth_headers
    assert_equal "application/json; charset=utf-8", response.content_type
  end

  private

  def auth_headers(project_id: nil)
    {
      "Authorization" => "Bearer valid_token",
      "X-Project-ID" => project_id || @project.id
    }
  end
end
