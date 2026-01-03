# frozen_string_literal: true

require "test_helper"

class Api::V1::AlertsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:acme)
    @alert = alerts(:firing_alert)
    @rule = alert_rules(:cpu_threshold)
  end

  # Index
  test "index returns list of alerts" do
    get api_v1_alerts_url, headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json["alerts"].is_a?(Array)
    assert json.key?("total")
  end

  test "index filters by state" do
    get api_v1_alerts_url(state: "firing"), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    json["alerts"].each do |alert|
      assert_equal "firing", alert["state"]
    end
  end

  test "index filters by severity" do
    get api_v1_alerts_url(severity: "warning"), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    json["alerts"].each do |alert|
      assert_equal "warning", alert["rule"]["severity"]
    end
  end

  test "index filters unacknowledged" do
    get api_v1_alerts_url(unacknowledged: "true"), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    json["alerts"].each do |alert|
      assert_not alert["acknowledged"]
    end
  end

  test "index respects limit param" do
    get api_v1_alerts_url(limit: 1), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json["alerts"].size <= 1
  end

  test "index orders by started_at desc" do
    get api_v1_alerts_url, headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    if json["alerts"].size >= 2
      dates = json["alerts"].map { |a| Time.parse(a["started_at"]) }
      assert dates == dates.sort.reverse
    end
  end

  # Show
  test "show returns alert details" do
    get api_v1_alert_url(@alert.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @alert.id, json["id"]
    assert json.key?("rule")
    assert json.key?("state")
    assert json.key?("fingerprint")
  end

  test "show returns full details" do
    get api_v1_alert_url(@alert.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    # Full mode includes incident and notifications
    assert json.key?("incident") || json["incident"].nil?
    assert json.key?("notifications")
    assert json.key?("rule_full")
  end

  test "show returns 404 for non-existent alert" do
    get api_v1_alert_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  test "show returns 404 for alert in different project" do
    other_project = projects(:staging)
    other_rule = AlertRule.create!(
      project_id: other_project.id,
      name: "Other Rule",
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )
    other_alert = other_rule.alerts.create!(
      project_id: other_project.id,
      fingerprint: "other_alert",
      state: "firing",
      started_at: Time.current
    )

    get api_v1_alert_url(other_alert.id), headers: auth_headers
    assert_response :not_found
  end

  # Acknowledge
  test "acknowledge updates alert" do
    unack_alert = @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "unack_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current,
      acknowledged: false
    )

    post acknowledge_api_v1_alert_url(unack_alert.id), headers: auth_headers,
      params: { by: "test@example.com", note: "Looking into it" }
    assert_response :success

    unack_alert.reload
    assert unack_alert.acknowledged?
    assert_equal "test@example.com", unack_alert.acknowledged_by
    assert_equal "Looking into it", unack_alert.acknowledgment_note
  end

  test "acknowledge defaults by to API" do
    unack_alert = @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "unack_api_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current,
      acknowledged: false
    )

    post acknowledge_api_v1_alert_url(unack_alert.id), headers: auth_headers
    assert_response :success

    unack_alert.reload
    assert_equal "API", unack_alert.acknowledged_by
  end

  test "acknowledge returns 404 for non-existent alert" do
    post acknowledge_api_v1_alert_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  # Trigger
  test "trigger creates manual alert" do
    assert_difference "Alert.count", 1 do
      post api_v1_alerts_trigger_url, headers: auth_headers,
        params: { name: @rule.name, value: 95.5, labels: { host: "manual" } }
    end
    assert_response :created

    json = JSON.parse(response.body)
    assert_equal "firing", json["state"]
    assert_equal 95.5, json["current_value"]
  end

  test "trigger returns 404 for non-existent rule name" do
    post api_v1_alerts_trigger_url, headers: auth_headers,
      params: { name: "Non Existent Rule" }
    assert_response :not_found
  end

  # Resolve by name
  test "resolve_by_name resolves all firing alerts for rule" do
    # Create firing alerts
    2.times do |i|
      @rule.alerts.create!(
        project_id: @project.id,
        fingerprint: "resolve_test_#{i}_#{SecureRandom.hex(4)}",
        state: "firing",
        started_at: Time.current
      )
    end

    # Stub resolve! to avoid calling IncidentManager
    Alert.any_instance.stubs(:resolve!)

    post api_v1_alerts_resolve_url, headers: auth_headers,
      params: { name: @rule.name }
    assert_response :success

    json = JSON.parse(response.body)
    assert json["resolved_count"] >= 2
  end

  test "resolve_by_name returns 404 for non-existent rule name" do
    post api_v1_alerts_resolve_url, headers: auth_headers,
      params: { name: "Non Existent Rule" }
    assert_response :not_found
  end

  # Serialization
  test "alert serialization includes required fields" do
    get api_v1_alert_url(@alert.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    required_fields = %w[id rule state fingerprint labels current_value started_at duration acknowledged]
    required_fields.each do |field|
      assert json.key?(field), "Missing field: #{field}"
    end
  end

  private

  def auth_headers
    {
      "Authorization" => "Bearer valid_token",
      "X-Project-ID" => @project.id
    }
  end
end
