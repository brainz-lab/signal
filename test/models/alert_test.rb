# frozen_string_literal: true

require "test_helper"

class AlertTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    rule = alert_rules(:cpu_threshold)
    alert = Alert.new(
      project_id: rule.project_id,
      alert_rule: rule,
      fingerprint: "unique_fingerprint_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current
    )
    assert alert.valid?, alert.errors.full_messages.join(", ")
  end

  test "should require fingerprint" do
    rule = alert_rules(:cpu_threshold)
    alert = Alert.new(
      project_id: rule.project_id,
      alert_rule: rule,
      state: "firing",
      started_at: Time.current
    )
    assert_not alert.valid?
    assert_includes alert.errors[:fingerprint], "can't be blank"
  end

  test "should require state" do
    rule = alert_rules(:cpu_threshold)
    alert = Alert.new(
      project_id: rule.project_id,
      alert_rule: rule,
      fingerprint: "test",
      started_at: Time.current
    )
    assert_not alert.valid?
    assert_includes alert.errors[:state], "can't be blank"
  end

  test "should require project_id" do
    rule = alert_rules(:cpu_threshold)
    alert = Alert.new(
      alert_rule: rule,
      fingerprint: "test",
      state: "firing",
      started_at: Time.current
    )
    assert_not alert.valid?
    assert_includes alert.errors[:project_id], "can't be blank"
  end

  test "should validate state inclusion" do
    rule = alert_rules(:cpu_threshold)
    alert = Alert.new(
      project_id: rule.project_id,
      alert_rule: rule,
      fingerprint: "test",
      state: "invalid",
      started_at: Time.current
    )
    assert_not alert.valid?
    assert_includes alert.errors[:state], "is not included in the list"
  end

  test "should accept valid states" do
    rule = alert_rules(:cpu_threshold)
    %w[pending firing resolved].each do |state|
      alert = Alert.new(
        project_id: rule.project_id,
        alert_rule: rule,
        fingerprint: "test_#{state}",
        state: state,
        started_at: Time.current
      )
      assert alert.valid?, "#{state} should be valid: #{alert.errors.full_messages.join(', ')}"
    end
  end

  # Associations
  test "should belong to alert_rule" do
    alert = alerts(:firing_alert)
    assert_not_nil alert.alert_rule
    assert_instance_of AlertRule, alert.alert_rule
  end

  test "should belong to incident optionally" do
    alert = alerts(:firing_alert)
    assert_respond_to alert, :incident
  end

  test "should have many notifications" do
    alert = alerts(:firing_alert)
    assert_respond_to alert, :notifications
  end

  test "should destroy notifications when destroyed" do
    alert = alerts(:firing_alert)
    notification_count = alert.notifications.count

    if notification_count > 0
      assert_difference "Notification.count", -notification_count do
        alert.destroy
      end
    end
  end

  # Scopes
  test "scope active returns pending and firing alerts" do
    active_alerts = Alert.active
    active_alerts.each do |alert|
      assert_includes %w[pending firing], alert.state
    end
  end

  test "scope firing returns only firing alerts" do
    firing_alerts = Alert.firing
    firing_alerts.each do |alert|
      assert_equal "firing", alert.state
    end
  end

  test "scope pending returns only pending alerts" do
    pending_alerts = Alert.pending
    pending_alerts.each do |alert|
      assert_equal "pending", alert.state
    end
  end

  test "scope resolved returns only resolved alerts" do
    resolved_alerts = Alert.resolved
    resolved_alerts.each do |alert|
      assert_equal "resolved", alert.state
    end
  end

  test "scope unacknowledged returns only unacknowledged alerts" do
    unack_alerts = Alert.unacknowledged
    unack_alerts.each do |alert|
      assert_not alert.acknowledged?
    end
  end

  test "scope recent orders by started_at desc" do
    recent_alerts = Alert.recent.limit(2).to_a
    if recent_alerts.size == 2
      assert recent_alerts[0].started_at >= recent_alerts[1].started_at
    end
  end

  test "scope for_project filters by project" do
    project = projects(:acme)
    project_alerts = Alert.for_project(project.id)
    project_alerts.each do |alert|
      assert_equal project.id, alert.project_id
    end
  end

  # Acknowledge
  test "acknowledge! sets acknowledged fields" do
    alert = alerts(:firing_alert)
    alert.acknowledge!(by: "user@example.com", note: "Looking into it")

    assert alert.acknowledged?
    assert_not_nil alert.acknowledged_at
    assert_equal "user@example.com", alert.acknowledged_by
    assert_equal "Looking into it", alert.acknowledgment_note
  end

  test "acknowledge! without note" do
    alert = alerts(:firing_alert)
    alert.acknowledge!(by: "user@example.com")

    assert alert.acknowledged?
    assert_equal "user@example.com", alert.acknowledged_by
    assert_nil alert.acknowledgment_note
  end

  # Duration
  test "duration returns time since started_at for active alerts" do
    alert = alerts(:firing_alert)
    duration = alert.duration

    assert duration > 0
    assert_kind_of Numeric, duration
  end

  test "duration returns time between started_at and resolved_at for resolved alerts" do
    alert = alerts(:resolved_alert)
    duration = alert.duration

    expected = alert.resolved_at - alert.started_at
    assert_in_delta expected, duration, 1
  end

  test "duration_human returns human readable duration" do
    alert = alerts(:firing_alert)
    human = alert.duration_human

    assert_kind_of String, human
  end

  # Severity delegation
  test "severity delegates to alert_rule" do
    alert = alerts(:firing_alert)
    assert_equal alert.alert_rule.severity, alert.severity
  end

  # Defaults
  test "should default acknowledged to false" do
    rule = alert_rules(:cpu_threshold)
    alert = Alert.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      fingerprint: "new_fingerprint_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current
    )
    assert_not alert.acknowledged?
  end

  test "should default notification_count to 0" do
    rule = alert_rules(:cpu_threshold)
    alert = Alert.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      fingerprint: "new_fingerprint_#{SecureRandom.hex(8)}",
      state: "pending",
      started_at: Time.current
    )
    assert_equal 0, alert.notification_count
  end

  # State transitions (basic - detailed in service tests)
  test "firing alert can be resolved" do
    alert = alerts(:firing_alert)
    alert.update!(state: "resolved", resolved_at: Time.current)
    assert_equal "resolved", alert.state
  end

  test "pending alert can be set to firing" do
    alert = alerts(:pending_alert)
    alert.update!(state: "firing", last_fired_at: Time.current)
    assert_equal "firing", alert.state
  end

  # Labels
  test "labels default to empty hash" do
    rule = alert_rules(:cpu_threshold)
    alert = Alert.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      fingerprint: "new_fingerprint_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current
    )
    assert_equal({}, alert.labels)
  end

  test "labels can store arbitrary data" do
    rule = alert_rules(:cpu_threshold)
    labels = { "host" => "server1", "region" => "us-east-1" }
    alert = Alert.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      fingerprint: "new_fingerprint_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current,
      labels: labels
    )
    assert_equal labels, alert.labels
  end
end
