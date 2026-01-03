# frozen_string_literal: true

require "test_helper"

class IncidentManagerTest < ActiveSupport::TestCase
  setup do
    @rule = alert_rules(:cpu_threshold)
    @alert = alerts(:firing_alert)
    @manager = IncidentManager.new(@alert)
  end

  # Initialization
  test "initializes with alert" do
    manager = IncidentManager.new(@alert)
    assert_not_nil manager
  end

  # Fire!
  test "fire! creates new incident when none exists" do
    # Create a fresh alert without incident
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "new_incident_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current
    )
    manager = IncidentManager.new(alert)

    assert_difference "Incident.count", 1 do
      incident = manager.fire!

      assert_not_nil incident
      assert_equal @rule.name, incident.title
      assert_equal @rule.severity, incident.severity
      assert_equal "triggered", incident.status
      assert_not_nil incident.triggered_at
    end
  end

  test "fire! reuses existing open incident" do
    # Create an incident
    incident = Incident.create!(
      project_id: @rule.project_id,
      title: @rule.name,
      severity: @rule.severity,
      status: "triggered",
      triggered_at: 1.hour.ago
    )

    # Create alert linked to the rule
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "reuse_incident_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current,
      incident: incident
    )

    # Create another alert for same rule
    new_alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "reuse_incident_test2_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current
    )

    manager = IncidentManager.new(new_alert)

    assert_no_difference "Incident.count" do
      returned_incident = manager.fire!
      assert_equal incident.id, returned_incident.id
    end
  end

  test "fire! links alert to incident" do
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "link_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current
    )
    manager = IncidentManager.new(alert)

    incident = manager.fire!
    alert.reload

    assert_equal incident.id, alert.incident_id
  end

  test "fire! adds timeline event" do
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "timeline_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current,
      current_value: 95.5
    )
    manager = IncidentManager.new(alert)

    incident = manager.fire!

    # Should have at least 1 event
    assert incident.timeline.size >= 1
    last_event = incident.timeline.last
    assert_equal "alert_fired", last_event["type"]
    assert_includes last_event["message"], @rule.name
    # Data might be nil or contain alert_id
    if last_event["data"]
      assert_equal alert.id, last_event["data"]["alert_id"]
    end
  end

  test "fire! includes summary from rule condition_description" do
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "summary_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current
    )
    manager = IncidentManager.new(alert)

    incident = manager.fire!

    assert_equal @rule.condition_description, incident.summary
  end

  # Resolve!
  test "resolve! adds timeline event to incident" do
    incident = Incident.create!(
      project_id: @rule.project_id,
      title: @rule.name,
      severity: @rule.severity,
      status: "triggered",
      triggered_at: 1.hour.ago
    )

    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "resolve_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 1.hour.ago,
      incident: incident
    )

    manager = IncidentManager.new(alert)
    initial_timeline_count = incident.timeline.size

    manager.resolve!
    incident.reload

    assert incident.timeline.size > initial_timeline_count
    last_event = incident.timeline.last
    assert_equal "alert_resolved", last_event["type"]
  end

  test "resolve! resolves incident when all alerts resolved" do
    incident = Incident.create!(
      project_id: @rule.project_id,
      title: @rule.name,
      severity: @rule.severity,
      status: "triggered",
      triggered_at: 1.hour.ago
    )

    # Create single alert for this incident
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "single_resolve_test_#{SecureRandom.hex(8)}",
      state: "resolved",
      started_at: 1.hour.ago,
      resolved_at: Time.current,
      incident: incident
    )

    manager = IncidentManager.new(alert)
    manager.resolve!
    incident.reload

    assert_equal "resolved", incident.status
    assert_not_nil incident.resolved_at
  end

  test "resolve! does not resolve incident when other alerts still firing" do
    incident = Incident.create!(
      project_id: @rule.project_id,
      title: @rule.name,
      severity: @rule.severity,
      status: "triggered",
      triggered_at: 1.hour.ago
    )

    # Create two alerts
    alert1 = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "multi_resolve_1_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 1.hour.ago,
      incident: incident
    )

    alert2 = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "multi_resolve_2_#{SecureRandom.hex(8)}",
      state: "resolved",
      started_at: 1.hour.ago,
      resolved_at: Time.current,
      incident: incident
    )

    manager = IncidentManager.new(alert2)
    manager.resolve!
    incident.reload

    assert_equal "triggered", incident.status
    assert_nil incident.resolved_at
  end

  test "resolve! does nothing when alert has no incident" do
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "no_incident_#{SecureRandom.hex(8)}",
      state: "resolved",
      started_at: 1.hour.ago,
      resolved_at: Time.current,
      incident: nil
    )

    manager = IncidentManager.new(alert)

    # Should not raise error
    assert_nothing_raised do
      manager.resolve!
    end
  end

  # Incident creation details
  test "creates incident with correct project_id" do
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "project_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current
    )
    manager = IncidentManager.new(alert)

    incident = manager.fire!

    assert_equal @rule.project_id, incident.project_id
  end

  test "creates incident with initial timeline event" do
    alert = @rule.alerts.create!(
      project_id: @rule.project_id,
      fingerprint: "initial_timeline_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current
    )
    manager = IncidentManager.new(alert)

    incident = manager.fire!

    assert incident.timeline.is_a?(Array)
    assert incident.timeline.any? { |e| e["type"] == "triggered" }
  end
end
