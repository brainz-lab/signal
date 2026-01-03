# frozen_string_literal: true

require "test_helper"

class AlertManagerTest < ActiveSupport::TestCase
  setup do
    @rule = alert_rules(:cpu_threshold)
    @manager = AlertManager.new(@rule)
  end

  # Initialization
  test "initializes with rule" do
    manager = AlertManager.new(@rule)
    assert_not_nil manager
  end

  # Process - Firing state
  test "process creates new alert for firing result" do
    fingerprint = "new_fingerprint_#{SecureRandom.hex(8)}"
    result = {
      state: "firing",
      value: 95.5,
      threshold: 80,
      fingerprint: fingerprint,
      labels: { host: "server1" }
    }

    # Stub fire! to avoid calling IncidentManager
    Alert.any_instance.stubs(:fire!)

    assert_difference "Alert.count", 1 do
      @manager.process(result)
    end

    alert = Alert.find_by(fingerprint: fingerprint)
    assert_not_nil alert
    assert_includes ["pending", "firing"], alert.state
    assert_equal 95.5, alert.current_value
    assert_equal 80, alert.threshold_value
  end

  test "process calls fire when pending period is zero and alert is pending long enough" do
    @rule.update!(pending_period: 0)
    fingerprint = "new_fingerprint_#{SecureRandom.hex(8)}"

    # Pre-create a pending alert that started in the past
    alert = @rule.alerts.create!(
      project: @rule.project,
      fingerprint: fingerprint,
      state: "pending",
      started_at: 1.hour.ago,
      current_value: 85
    )

    result = {
      state: "firing",
      value: 95.5,
      threshold: 80,
      fingerprint: fingerprint,
      labels: {}
    }

    # Expect fire! to be called
    Alert.any_instance.expects(:fire!).at_least_once

    @manager.process(result)
  end

  test "process keeps pending alert pending when pending period not elapsed" do
    @rule.update!(pending_period: 300) # 5 minutes
    result = {
      state: "firing",
      value: 95.5,
      threshold: 80,
      fingerprint: "new_pending_#{SecureRandom.hex(8)}",
      labels: {}
    }

    @manager.process(result)
    alert = Alert.find_by(fingerprint: result[:fingerprint])

    assert_equal "pending", alert.state
    # Process again immediately - should still be pending
    @manager.process(result)
    alert.reload

    assert_equal "pending", alert.state
  end

  test "process updates existing firing alert" do
    alert = alerts(:firing_alert)
    result = {
      state: "firing",
      value: 98.0,
      threshold: 80,
      fingerprint: alert.fingerprint,
      labels: alert.labels
    }

    old_last_fired_at = alert.last_fired_at
    @manager.process(result)
    alert.reload

    assert_equal "firing", alert.state
    assert alert.last_fired_at > old_last_fired_at
  end

  test "process resets resolved alert to pending for new firing" do
    alert = alerts(:resolved_alert)
    result = {
      state: "firing",
      value: 95.0,
      threshold: 80,
      fingerprint: alert.fingerprint,
      labels: {}
    }

    @manager.process(result)
    alert.reload

    assert_equal "pending", alert.state
    assert_nil alert.resolved_at
    assert_not alert.acknowledged?
  end

  # Process - OK state
  test "process ignores ok state for non-existent alert" do
    result = {
      state: "ok",
      value: 45.0,
      fingerprint: "non_existent_fingerprint",
      labels: {}
    }

    assert_no_difference "Alert.count" do
      @manager.process(result)
    end
  end

  test "process destroys pending alert on ok state" do
    # Create a pending alert
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "pending_to_destroy_#{SecureRandom.hex(8)}",
      state: "pending",
      started_at: Time.current
    )

    result = {
      state: "ok",
      value: 45.0,
      fingerprint: alert.fingerprint,
      labels: {}
    }

    assert_difference "Alert.count", -1 do
      @manager.process(result)
    end
  end

  test "process resolves firing alert when ok long enough" do
    alert = alerts(:firing_alert)
    @rule.update!(resolve_period: 0)

    # Create OK history entries
    AlertHistory.create!(
      project_id: @rule.project_id,
      alert_rule: @rule,
      fingerprint: alert.fingerprint,
      state: "ok",
      timestamp: Time.current
    )

    # Expect resolve! to be called
    Alert.any_instance.expects(:resolve!).at_least_once

    result = {
      state: "ok",
      value: 45.0,
      fingerprint: alert.fingerprint,
      labels: {}
    }

    @manager.process(result)
  end

  # Fingerprint handling
  test "finds existing alert by fingerprint" do
    alert = alerts(:firing_alert)
    result = {
      state: "firing",
      value: 99.0,
      threshold: 80,
      fingerprint: alert.fingerprint,
      labels: {}
    }

    assert_no_difference "Alert.count" do
      @manager.process(result)
    end
  end

  test "creates new alert for new fingerprint" do
    result = {
      state: "firing",
      value: 95.5,
      threshold: 80,
      fingerprint: "completely_new_#{SecureRandom.hex(8)}",
      labels: {}
    }

    assert_difference "Alert.count", 1 do
      @manager.process(result)
    end
  end

  # Value updates
  test "updates current_value on firing" do
    alert = alerts(:firing_alert)
    old_value = alert.current_value

    result = {
      state: "firing",
      value: old_value + 10,
      threshold: 80,
      fingerprint: alert.fingerprint,
      labels: {}
    }

    @manager.process(result)
    alert.reload

    assert_equal old_value + 10, alert.current_value
  end

  test "updates labels on firing" do
    alert = alerts(:firing_alert)
    new_labels = { "new_key" => "new_value" }

    result = {
      state: "firing",
      value: 95.0,
      threshold: 80,
      fingerprint: alert.fingerprint,
      labels: new_labels
    }

    @manager.process(result)
    alert.reload

    assert_equal new_labels, alert.labels
  end
end
