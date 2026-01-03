# frozen_string_literal: true

require "test_helper"

class Api::V1::IncidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:acme)
    @incident = incidents(:active_incident)
  end

  # Index
  test "index returns list of incidents" do
    get api_v1_incidents_url, headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json["incidents"].is_a?(Array)
  end

  test "index filters by status" do
    get api_v1_incidents_url(status: "triggered"), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    json["incidents"].each do |incident|
      assert_equal "triggered", incident["status"]
    end
  end

  test "index filters by severity" do
    get api_v1_incidents_url(severity: "critical"), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    json["incidents"].each do |incident|
      assert_equal "critical", incident["severity"]
    end
  end

  # Show
  test "show returns incident details" do
    get api_v1_incident_url(@incident.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @incident.id, json["id"]
    assert_equal @incident.title, json["title"]
  end

  test "show returns 404 for non-existent incident" do
    get api_v1_incident_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  # Acknowledge
  test "acknowledge updates incident" do
    post acknowledge_api_v1_incident_url(@incident.id), headers: auth_headers,
      params: { by: "oncall@example.com" }
    assert_response :success

    @incident.reload
    assert_equal "acknowledged", @incident.status
    assert_equal "oncall@example.com", @incident.acknowledged_by
  end

  test "acknowledge returns 404 for non-existent incident" do
    post acknowledge_api_v1_incident_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  # Resolve
  test "resolve updates incident" do
    post resolve_api_v1_incident_url(@incident.id), headers: auth_headers,
      params: { by: "admin@example.com", note: "Fixed" }
    assert_response :success

    @incident.reload
    assert_equal "resolved", @incident.status
    assert_equal "admin@example.com", @incident.resolved_by
    assert_equal "Fixed", @incident.resolution_note
  end

  private

  def auth_headers
    {
      "Authorization" => "Bearer valid_token",
      "X-Project-ID" => @project.id
    }
  end
end
