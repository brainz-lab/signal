# frozen_string_literal: true

require "test_helper"

class Api::V1::RulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:acme)
    @rule = alert_rules(:cpu_threshold)
  end

  # Index
  test "index returns list of rules" do
    get api_v1_rules_url, headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json["rules"].is_a?(Array)
  end

  test "index filters by source" do
    get api_v1_rules_url(source: "flux"), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    json["rules"].each do |rule|
      assert_equal "flux", rule["source"]
    end
  end

  test "index filters enabled only" do
    get api_v1_rules_url(enabled: "true"), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    json["rules"].each do |rule|
      assert rule["enabled"]
    end
  end

  # Show
  test "show returns rule details" do
    get api_v1_rule_url(@rule.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @rule.id, json["id"]
    assert_equal @rule.name, json["name"]
  end

  test "show returns full details" do
    get api_v1_rule_url(@rule.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    # Full mode includes additional fields
    assert json.key?("description")
    assert json.key?("operator")
    assert json.key?("threshold")
    assert json.key?("query")
  end

  test "show returns 404 for non-existent rule" do
    get api_v1_rule_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  # Create
  test "create creates new rule" do
    rule_params = {
      rule: {
        name: "New Test Rule",
        source: "flux",
        source_name: "test_metric",
        rule_type: "threshold",
        operator: "gt",
        threshold: 90,
        severity: "critical",
        aggregation: "avg",
        window: "5m"
      }
    }

    assert_difference "AlertRule.count", 1 do
      post api_v1_rules_url, headers: auth_headers, params: rule_params
    end
    assert_response :created

    json = JSON.parse(response.body)
    assert_equal "New Test Rule", json["name"]
  end

  test "create returns errors for invalid params" do
    rule_params = {
      rule: {
        name: "", # Invalid - blank name
        source: "invalid_source",
        rule_type: "threshold"
      }
    }

    assert_no_difference "AlertRule.count" do
      post api_v1_rules_url, headers: auth_headers, params: rule_params
    end
    assert_response :unprocessable_entity

    json = JSON.parse(response.body)
    assert json["errors"].present?
  end

  test "create auto-generates slug" do
    rule_params = {
      rule: {
        name: "My New Alert Rule",
        source: "flux",
        rule_type: "threshold",
        severity: "warning"
      }
    }

    post api_v1_rules_url, headers: auth_headers, params: rule_params
    assert_response :created

    json = JSON.parse(response.body)
    assert_equal "my-new-alert-rule", json["slug"]
  end

  # Update
  test "update updates rule" do
    patch api_v1_rule_url(@rule.id), headers: auth_headers,
      params: { rule: { threshold: 95, severity: "critical" } }
    assert_response :success

    @rule.reload
    assert_equal 95, @rule.threshold
    assert_equal "critical", @rule.severity
  end

  test "update returns errors for invalid params" do
    patch api_v1_rule_url(@rule.id), headers: auth_headers,
      params: { rule: { source: "invalid_source" } }
    assert_response :unprocessable_entity
  end

  test "update returns 404 for non-existent rule" do
    patch api_v1_rule_url("non-existent-uuid"), headers: auth_headers,
      params: { rule: { threshold: 95 } }
    assert_response :not_found
  end

  # Destroy
  test "destroy deletes rule" do
    rule_to_delete = AlertRule.create!(
      project_id: @project.id,
      name: "To Delete",
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )

    assert_difference "AlertRule.count", -1 do
      delete api_v1_rule_url(rule_to_delete.id), headers: auth_headers
    end
    assert_response :no_content
  end

  test "destroy returns 404 for non-existent rule" do
    delete api_v1_rule_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  # Mute
  test "mute mutes rule" do
    post mute_api_v1_rule_url(@rule.id), headers: auth_headers,
      params: { reason: "Maintenance" }
    assert_response :success

    @rule.reload
    assert @rule.muted?
    assert_equal "Maintenance", @rule.muted_reason
  end

  test "mute with until time" do
    until_time = 2.hours.from_now.iso8601
    post mute_api_v1_rule_url(@rule.id), headers: auth_headers,
      params: { until: until_time, reason: "Temporary" }
    assert_response :success

    @rule.reload
    assert @rule.muted?
    assert_not_nil @rule.muted_until
  end

  test "mute returns 404 for non-existent rule" do
    post mute_api_v1_rule_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  # Unmute
  test "unmute unmutes rule" do
    @rule.mute!(reason: "Test")

    post unmute_api_v1_rule_url(@rule.id), headers: auth_headers
    assert_response :success

    @rule.reload
    assert_not @rule.muted?
  end

  test "unmute returns 404 for non-existent rule" do
    post unmute_api_v1_rule_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  # Test
  test "test evaluates rule and returns result" do
    # Stub data source
    DataSources::Flux.any_instance.stubs(:query).returns(75.0)

    post test_api_v1_rule_url(@rule.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json.key?("rule")
    assert json.key?("result")
    assert json["result"].key?("state")
  end

  test "test returns 404 for non-existent rule" do
    post test_api_v1_rule_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  # Serialization
  test "rule serialization includes required fields" do
    get api_v1_rule_url(@rule.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    required_fields = %w[id name slug source rule_type condition severity enabled muted]
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
