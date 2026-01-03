# frozen_string_literal: true

require "test_helper"

class AlertRuleTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    project = projects(:acme)
    rule = AlertRule.new(
      project_id: project.id,
      name: "New Rule",
      source: "flux",
      rule_type: "threshold",
      severity: "warning",
      operator: "gt",
      threshold: 80
    )
    assert rule.valid?, rule.errors.full_messages.join(", ")
  end

  test "should require name" do
    rule = AlertRule.new(source: "flux", rule_type: "threshold")
    assert_not rule.valid?
    assert_includes rule.errors[:name], "can't be blank"
  end

  test "should require project_id" do
    rule = AlertRule.new(name: "Test", source: "flux", rule_type: "threshold")
    assert_not rule.valid?
    assert_includes rule.errors[:project_id], "can't be blank"
  end

  test "should require source" do
    project = projects(:acme)
    rule = AlertRule.new(project_id: project.id, name: "Test", rule_type: "threshold")
    assert_not rule.valid?
    assert_includes rule.errors[:source], "can't be blank"
  end

  test "should validate source inclusion" do
    project = projects(:acme)
    rule = AlertRule.new(project_id: project.id, name: "Test", source: "invalid", rule_type: "threshold")
    assert_not rule.valid?
    assert_includes rule.errors[:source], "is not included in the list"
  end

  test "should accept valid sources" do
    project = projects(:acme)
    %w[flux pulse reflex recall].each do |source|
      rule = AlertRule.new(
        project_id: project.id,
        name: "Test #{source}",
        source: source,
        rule_type: "threshold",
        severity: "warning"
      )
      assert rule.valid?, "#{source} should be valid: #{rule.errors.full_messages.join(', ')}"
    end
  end

  test "should require rule_type" do
    project = projects(:acme)
    rule = AlertRule.new(project_id: project.id, name: "Test", source: "flux")
    assert_not rule.valid?
    assert_includes rule.errors[:rule_type], "can't be blank"
  end

  test "should validate rule_type inclusion" do
    project = projects(:acme)
    rule = AlertRule.new(project_id: project.id, name: "Test", source: "flux", rule_type: "invalid")
    assert_not rule.valid?
    assert_includes rule.errors[:rule_type], "is not included in the list"
  end

  test "should accept valid rule_types" do
    project = projects(:acme)
    %w[threshold anomaly absence composite].each do |type|
      rule = AlertRule.new(
        project_id: project.id,
        name: "Test #{type}",
        source: "flux",
        rule_type: type,
        severity: "warning"
      )
      assert rule.valid?, "#{type} should be valid: #{rule.errors.full_messages.join(', ')}"
    end
  end

  test "should validate severity inclusion" do
    project = projects(:acme)
    rule = AlertRule.new(project_id: project.id, name: "Test", source: "flux", rule_type: "threshold", severity: "invalid")
    assert_not rule.valid?
    assert_includes rule.errors[:severity], "is not included in the list"
  end

  test "should accept valid severities" do
    project = projects(:acme)
    %w[info warning critical].each do |sev|
      rule = AlertRule.new(
        project_id: project.id,
        name: "Test #{sev}",
        source: "flux",
        rule_type: "threshold",
        severity: sev
      )
      assert rule.valid?, "#{sev} should be valid: #{rule.errors.full_messages.join(', ')}"
    end
  end

  test "should enforce unique slug per project" do
    existing = alert_rules(:cpu_threshold)
    duplicate = AlertRule.new(
      project_id: existing.project_id,
      name: "Different Name",
      slug: existing.slug,
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "should allow same slug in different projects" do
    rule1 = alert_rules(:cpu_threshold)
    staging_project = projects(:staging)

    rule2 = AlertRule.new(
      project_id: staging_project.id,
      name: "Same Slug Different Project",
      slug: rule1.slug,
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )
    assert rule2.valid?
  end

  # Slug generation
  test "should auto-generate slug from name on create" do
    project = projects(:acme)
    rule = AlertRule.new(
      project_id: project.id,
      name: "My New Alert Rule",
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )
    rule.save!
    assert_equal "my-new-alert-rule", rule.slug
  end

  test "should not override existing slug" do
    project = projects(:acme)
    rule = AlertRule.new(
      project_id: project.id,
      name: "Custom Name",
      slug: "custom-slug",
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )
    rule.save!
    assert_equal "custom-slug", rule.slug
  end

  # Scopes
  test "scope enabled returns only enabled rules" do
    enabled_rules = AlertRule.enabled
    enabled_rules.each do |rule|
      assert rule.enabled?, "Rule #{rule.name} should be enabled"
    end
  end

  test "scope active returns enabled and not muted rules" do
    active_rules = AlertRule.active
    active_rules.each do |rule|
      assert rule.enabled?, "Rule #{rule.name} should be enabled"
      assert_not rule.muted?, "Rule #{rule.name} should not be muted"
    end
  end

  test "scope by_source filters by source" do
    flux_rules = AlertRule.by_source("flux")
    flux_rules.each do |rule|
      assert_equal "flux", rule.source
    end
  end

  test "scope for_project filters by project" do
    project = projects(:acme)
    project_rules = AlertRule.for_project(project.id)
    project_rules.each do |rule|
      assert_equal project.id, rule.project_id
    end
  end

  # Muting
  test "mute! sets muted to true" do
    rule = alert_rules(:cpu_threshold)
    rule.mute!
    assert rule.muted
    assert_nil rule.muted_until
  end

  test "mute! with until_time sets muted_until" do
    rule = alert_rules(:cpu_threshold)
    until_time = 2.hours.from_now
    rule.mute!(until_time: until_time, reason: "Testing")

    assert rule.muted
    assert_in_delta until_time.to_i, rule.muted_until.to_i, 1
    assert_equal "Testing", rule.muted_reason
  end

  test "unmute! clears muting" do
    rule = alert_rules(:muted_rule)
    rule.unmute!

    assert_not rule.muted
    assert_nil rule.muted_until
    assert_nil rule.muted_reason
  end

  test "muted? returns false when not muted" do
    rule = alert_rules(:cpu_threshold)
    assert_not rule.muted?
  end

  test "muted? returns true when muted indefinitely" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(muted: true, muted_until: nil)
    assert rule.muted?
  end

  test "muted? returns true when muted_until is in the future" do
    rule = alert_rules(:muted_rule)
    assert rule.muted?
  end

  test "muted? returns false when muted_until is in the past" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(muted: true, muted_until: 1.hour.ago)
    assert_not rule.muted?
  end

  # Associations
  test "should have many alerts" do
    rule = alert_rules(:cpu_threshold)
    assert_respond_to rule, :alerts
  end

  test "should have many alert_histories" do
    rule = alert_rules(:cpu_threshold)
    assert_respond_to rule, :alert_histories
  end

  test "should belong to escalation_policy optionally" do
    rule = alert_rules(:cpu_threshold)
    assert_respond_to rule, :escalation_policy
  end

  test "should destroy associated alerts when destroyed" do
    rule = alert_rules(:cpu_threshold)
    alert_count = rule.alerts.count

    assert_difference "Alert.count", -alert_count do
      rule.destroy
    end
  end

  # Notification channels
  test "notification_channels returns channels from notify_channels array" do
    rule = alert_rules(:cpu_threshold)
    channel = notification_channels(:slack_channel)
    rule.update!(notify_channels: [ channel.id ])

    channels = rule.notification_channels
    assert_includes channels, channel
  end

  test "notification_channels returns empty when notify_channels is empty" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(notify_channels: [])

    assert_empty rule.notification_channels
  end

  # Condition description
  test "condition_description for threshold rule" do
    rule = alert_rules(:cpu_threshold)
    desc = rule.condition_description

    assert_includes desc, rule.aggregation
    assert_includes desc, ">"
    assert_includes desc, rule.threshold.to_s
  end

  test "condition_description for anomaly rule" do
    rule = alert_rules(:anomaly_detection)
    desc = rule.condition_description

    assert_includes desc, "Anomaly"
    assert_includes desc, rule.sensitivity.to_s
  end

  test "condition_description for absence rule" do
    rule = alert_rules(:log_absence)
    desc = rule.condition_description

    assert_includes desc, "No data"
    assert_includes desc, rule.expected_interval
  end

  # Operators
  test "OPERATORS constant has all operators" do
    expected = %w[gt gte lt lte eq neq]
    expected.each do |op|
      assert AlertRule::OPERATORS.key?(op), "Missing operator: #{op}"
    end
  end

  # Defaults
  test "should default enabled to true" do
    project = projects(:acme)
    rule = AlertRule.create!(
      project_id: project.id,
      name: "Default Test",
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )
    assert rule.enabled?
  end

  test "should default muted to false" do
    project = projects(:acme)
    rule = AlertRule.create!(
      project_id: project.id,
      name: "Default Test",
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )
    assert_not rule.muted?
  end

  test "should default evaluation_interval to 60" do
    project = projects(:acme)
    rule = AlertRule.create!(
      project_id: project.id,
      name: "Default Test",
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )
    assert_equal 60, rule.evaluation_interval
  end
end
