# frozen_string_literal: true

require "test_helper"

class IncidentTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    project = projects(:acme)
    incident = Incident.new(
      project_id: project.id,
      title: "New Incident",
      severity: "warning",
      status: "triggered",
      triggered_at: Time.current
    )
    assert incident.valid?, incident.errors.full_messages.join(", ")
  end

  test "should require title" do
    incident = Incident.new(severity: "warning", status: "triggered")
    assert_not incident.valid?
    assert_includes incident.errors[:title], "can't be blank"
  end

  test "should require project_id" do
    incident = Incident.new(title: "Test", severity: "warning", status: "triggered")
    assert_not incident.valid?
    assert_includes incident.errors[:project_id], "can't be blank"
  end

  test "should validate status inclusion" do
    project = projects(:acme)
    incident = Incident.new(
      project_id: project.id,
      title: "Test",
      severity: "warning",
      status: "invalid",
      triggered_at: Time.current
    )
    assert_not incident.valid?
    assert_includes incident.errors[:status], "is not included in the list"
  end

  test "should accept valid statuses" do
    project = projects(:acme)
    %w[triggered acknowledged resolved].each do |status|
      incident = Incident.new(
        project_id: project.id,
        title: "Test #{status}",
        severity: "warning",
        status: status,
        triggered_at: Time.current
      )
      assert incident.valid?, "#{status} should be valid: #{incident.errors.full_messages.join(', ')}"
    end
  end

  test "should validate severity inclusion" do
    project = projects(:acme)
    incident = Incident.new(
      project_id: project.id,
      title: "Test",
      severity: "invalid",
      status: "triggered",
      triggered_at: Time.current
    )
    assert_not incident.valid?
    assert_includes incident.errors[:severity], "is not included in the list"
  end

  test "should accept valid severities" do
    project = projects(:acme)
    %w[info warning critical].each do |sev|
      incident = Incident.new(
        project_id: project.id,
        title: "Test #{sev}",
        severity: sev,
        status: "triggered",
        triggered_at: Time.current
      )
      assert incident.valid?, "#{sev} should be valid: #{incident.errors.full_messages.join(', ')}"
    end
  end

  # Associations
  test "should have many alerts" do
    incident = incidents(:active_incident)
    assert_respond_to incident, :alerts
  end

  test "should have many notifications" do
    incident = incidents(:active_incident)
    assert_respond_to incident, :notifications
  end

  test "alerts are nullified when incident is destroyed" do
    incident = incidents(:active_incident)
    alert = alerts(:firing_alert)
    alert.update!(incident: incident)

    incident.destroy
    alert.reload

    assert_nil alert.incident_id
  end

  # Scopes
  test "scope open returns triggered and acknowledged incidents" do
    open_incidents = Incident.open
    open_incidents.each do |incident|
      assert_includes %w[triggered acknowledged], incident.status
    end
  end

  test "scope resolved returns only resolved incidents" do
    resolved_incidents = Incident.resolved
    resolved_incidents.each do |incident|
      assert_equal "resolved", incident.status
    end
  end

  test "scope by_severity filters by severity" do
    critical_incidents = Incident.by_severity("critical")
    critical_incidents.each do |incident|
      assert_equal "critical", incident.severity
    end
  end

  test "scope recent orders by triggered_at desc" do
    recent_incidents = Incident.recent.limit(2).to_a
    if recent_incidents.size == 2
      assert recent_incidents[0].triggered_at >= recent_incidents[1].triggered_at
    end
  end

  test "scope for_project filters by project" do
    project = projects(:acme)
    project_incidents = Incident.for_project(project.id)
    project_incidents.each do |incident|
      assert_equal project.id, incident.project_id
    end
  end

  # Acknowledge
  test "acknowledge! sets acknowledged fields" do
    incident = incidents(:active_incident)
    incident.acknowledge!(by: "user@example.com")

    assert_equal "acknowledged", incident.status
    assert_not_nil incident.acknowledged_at
    assert_equal "user@example.com", incident.acknowledged_by
  end

  test "acknowledge! does nothing if already resolved" do
    incident = incidents(:resolved_incident)
    original_status = incident.status
    original_acknowledged_by = incident.acknowledged_by

    incident.acknowledge!(by: "newuser@example.com")

    assert_equal original_status, incident.status
    # acknowledged_by should not change
    assert_equal original_acknowledged_by, incident.acknowledged_by
  end

  test "acknowledge! adds timeline event" do
    incident = incidents(:active_incident)
    initial_timeline_count = incident.timeline.size

    incident.acknowledge!(by: "user@example.com")

    assert_equal initial_timeline_count + 1, incident.timeline.size
    last_event = incident.timeline.last
    assert_equal "acknowledged", last_event["type"]
    assert_equal "user@example.com", last_event["by"]
  end

  # Resolve
  test "resolve! sets resolved fields" do
    incident = incidents(:acknowledged_incident)
    incident.resolve!(by: "user@example.com", note: "Fixed the issue")

    assert_equal "resolved", incident.status
    assert_not_nil incident.resolved_at
    assert_equal "user@example.com", incident.resolved_by
    assert_equal "Fixed the issue", incident.resolution_note
  end

  test "resolve! adds timeline event" do
    incident = incidents(:acknowledged_incident)
    initial_timeline_count = incident.timeline.size

    incident.resolve!(by: "user@example.com", note: "Issue resolved")

    assert_equal initial_timeline_count + 1, incident.timeline.size
    last_event = incident.timeline.last
    assert_equal "resolved", last_event["type"]
    assert_equal "user@example.com", last_event["by"]
    assert_equal "Issue resolved", last_event["message"]
  end

  # Timeline
  test "add_timeline_event appends to timeline" do
    incident = incidents(:active_incident)
    initial_count = incident.timeline.size

    incident.add_timeline_event(
      type: "comment",
      message: "Investigating the issue",
      by: "user@example.com"
    )

    assert_equal initial_count + 1, incident.timeline.size
    last_event = incident.timeline.last
    assert_equal "comment", last_event["type"]
    assert_equal "Investigating the issue", last_event["message"]
    assert_equal "user@example.com", last_event["by"]
    assert_not_nil last_event["at"]
  end

  test "add_timeline_event handles nil values" do
    incident = incidents(:active_incident)

    incident.add_timeline_event(type: "update", message: nil, by: nil)

    last_event = incident.timeline.last
    assert_equal "update", last_event["type"]
    assert_nil last_event["message"]
    assert_nil last_event["by"]
  end

  test "add_timeline_event includes additional data" do
    incident = incidents(:active_incident)

    incident.add_timeline_event(
      type: "metric",
      data: { value: 95, threshold: 80 }
    )

    last_event = incident.timeline.last
    assert_equal 95, last_event["value"]
    assert_equal 80, last_event["threshold"]
  end

  # Duration
  test "duration returns time since triggered_at for open incidents" do
    incident = incidents(:active_incident)
    duration = incident.duration

    assert duration > 0
    assert_kind_of Numeric, duration
  end

  test "duration returns time between triggered_at and resolved_at for resolved incidents" do
    incident = incidents(:resolved_incident)
    duration = incident.duration

    expected = incident.resolved_at - incident.triggered_at
    assert_in_delta expected, duration, 1
  end

  # Defaults
  test "timeline defaults to empty array" do
    project = projects(:acme)
    incident = Incident.create!(
      project_id: project.id,
      title: "New Incident",
      severity: "warning",
      status: "triggered",
      triggered_at: Time.current
    )
    assert_equal [], incident.timeline
  end

  test "affected_services defaults to empty array" do
    project = projects(:acme)
    incident = Incident.create!(
      project_id: project.id,
      title: "New Incident",
      severity: "warning",
      status: "triggered",
      triggered_at: Time.current
    )
    assert_equal [], incident.affected_services
  end

  # Affected services
  test "affected_services can store array of service names" do
    project = projects(:acme)
    services = %w[api database cache]
    incident = Incident.create!(
      project_id: project.id,
      title: "Multi-service Incident",
      severity: "critical",
      status: "triggered",
      triggered_at: Time.current,
      affected_services: services
    )
    assert_equal services, incident.affected_services
  end
end
