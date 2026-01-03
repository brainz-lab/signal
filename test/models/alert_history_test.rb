# frozen_string_literal: true

require "test_helper"

class AlertHistoryTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    rule = alert_rules(:cpu_threshold)
    history = AlertHistory.new(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: Time.current,
      state: "ok",
      value: 45.5
    )
    assert history.valid?, history.errors.full_messages.join(", ")
  end

  test "should require timestamp" do
    rule = alert_rules(:cpu_threshold)
    history = AlertHistory.new(
      project_id: rule.project_id,
      alert_rule: rule,
      state: "ok"
    )
    assert_not history.valid?
    assert_includes history.errors[:timestamp], "can't be blank"
  end

  test "should require state" do
    rule = alert_rules(:cpu_threshold)
    history = AlertHistory.new(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: Time.current
    )
    assert_not history.valid?
    assert_includes history.errors[:state], "can't be blank"
  end

  test "should require project_id" do
    rule = alert_rules(:cpu_threshold)
    history = AlertHistory.new(
      alert_rule: rule,
      timestamp: Time.current,
      state: "ok"
    )
    assert_not history.valid?
    assert_includes history.errors[:project_id], "can't be blank"
  end

  test "should validate state inclusion" do
    rule = alert_rules(:cpu_threshold)
    history = AlertHistory.new(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: Time.current,
      state: "invalid"
    )
    assert_not history.valid?
    assert_includes history.errors[:state], "is not included in the list"
  end

  test "should accept valid states" do
    rule = alert_rules(:cpu_threshold)
    %w[ok pending firing].each do |state|
      history = AlertHistory.new(
        project_id: rule.project_id,
        alert_rule: rule,
        timestamp: Time.current,
        state: state
      )
      assert history.valid?, "#{state} should be valid: #{history.errors.full_messages.join(', ')}"
    end
  end

  # Associations
  test "should belong to alert_rule" do
    history = alert_histories(:cpu_history_ok)
    assert_not_nil history.alert_rule
    assert_instance_of AlertRule, history.alert_rule
  end

  # Scopes
  test "scope for_project filters by project" do
    project = projects(:acme)
    project_histories = AlertHistory.for_project(project.id)
    project_histories.each do |history|
      assert_equal project.id, history.project_id
    end
  end

  test "scope recent orders by timestamp desc" do
    recent_histories = AlertHistory.recent.limit(2).to_a
    if recent_histories.size == 2
      assert recent_histories[0].timestamp >= recent_histories[1].timestamp
    end
  end

  # Value storage
  test "can store float value" do
    rule = alert_rules(:cpu_threshold)
    history = AlertHistory.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: Time.current,
      state: "ok",
      value: 95.75
    )
    assert_in_delta 95.75, history.value, 0.01
  end

  test "value can be nil" do
    rule = alert_rules(:cpu_threshold)
    history = AlertHistory.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: Time.current,
      state: "ok",
      value: nil
    )
    assert_nil history.value
  end

  # Labels storage
  test "labels defaults to empty hash" do
    rule = alert_rules(:cpu_threshold)
    history = AlertHistory.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: Time.current,
      state: "ok"
    )
    assert_equal({}, history.labels)
  end

  test "labels can store arbitrary data" do
    rule = alert_rules(:cpu_threshold)
    labels = { "host" => "server1", "region" => "us-east-1" }
    history = AlertHistory.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: Time.current,
      state: "firing",
      labels: labels
    )
    assert_equal labels, history.labels
  end

  # Fingerprint
  test "can store fingerprint" do
    rule = alert_rules(:cpu_threshold)
    history = AlertHistory.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: Time.current,
      state: "firing",
      fingerprint: "cpu_threshold_host1"
    )
    assert_equal "cpu_threshold_host1", history.fingerprint
  end

  # State transitions tracking
  test "can track state progression" do
    rule = alert_rules(:cpu_threshold)

    # Create history entries showing state progression
    ok_history = AlertHistory.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: 2.hours.ago,
      state: "ok",
      value: 45.0
    )

    pending_history = AlertHistory.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: 1.hour.ago,
      state: "pending",
      value: 82.0
    )

    firing_history = AlertHistory.create!(
      project_id: rule.project_id,
      alert_rule: rule,
      timestamp: 30.minutes.ago,
      state: "firing",
      value: 95.0
    )

    # Query recent history for this rule
    histories = AlertHistory.where(alert_rule: rule).recent.limit(3)
    assert_equal 3, histories.count
    assert_equal "firing", histories.first.state
  end

  # Fixtures
  test "cpu_history_ok fixture is valid" do
    history = alert_histories(:cpu_history_ok)
    assert history.valid?
    assert_equal "ok", history.state
  end

  test "cpu_history_pending fixture is valid" do
    history = alert_histories(:cpu_history_pending)
    assert history.valid?
    assert_equal "pending", history.state
  end

  test "cpu_history_firing fixture is valid" do
    history = alert_histories(:cpu_history_firing)
    assert history.valid?
    assert_equal "firing", history.state
  end

  test "history fixtures have chronological order" do
    ok = alert_histories(:cpu_history_ok)
    pending = alert_histories(:cpu_history_pending)
    firing = alert_histories(:cpu_history_firing)

    assert ok.timestamp < pending.timestamp
    assert pending.timestamp < firing.timestamp
  end
end
