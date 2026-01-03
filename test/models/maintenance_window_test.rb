# frozen_string_literal: true

require "test_helper"

class MaintenanceWindowTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    project = projects(:acme)
    window = MaintenanceWindow.new(
      project_id: project.id,
      name: "New Maintenance",
      starts_at: 1.hour.from_now,
      ends_at: 3.hours.from_now
    )
    assert window.valid?, window.errors.full_messages.join(", ")
  end

  test "should require name" do
    window = MaintenanceWindow.new(starts_at: Time.current, ends_at: 1.hour.from_now)
    assert_not window.valid?
    assert_includes window.errors[:name], "can't be blank"
  end

  test "should require project_id" do
    window = MaintenanceWindow.new(name: "Test", starts_at: Time.current, ends_at: 1.hour.from_now)
    assert_not window.valid?
    assert_includes window.errors[:project_id], "can't be blank"
  end

  test "should require starts_at" do
    project = projects(:acme)
    window = MaintenanceWindow.new(
      project_id: project.id,
      name: "Test",
      ends_at: 1.hour.from_now
    )
    assert_not window.valid?
    assert_includes window.errors[:starts_at], "can't be blank"
  end

  test "should require ends_at" do
    project = projects(:acme)
    window = MaintenanceWindow.new(
      project_id: project.id,
      name: "Test",
      starts_at: Time.current
    )
    assert_not window.valid?
    assert_includes window.errors[:ends_at], "can't be blank"
  end

  test "ends_at must be after starts_at" do
    project = projects(:acme)
    window = MaintenanceWindow.new(
      project_id: project.id,
      name: "Invalid Window",
      starts_at: 2.hours.from_now,
      ends_at: 1.hour.from_now
    )
    assert_not window.valid?
    assert_includes window.errors[:ends_at], "must be after starts_at"
  end

  test "ends_at equal to starts_at is invalid" do
    project = projects(:acme)
    time = 1.hour.from_now
    window = MaintenanceWindow.new(
      project_id: project.id,
      name: "Invalid Window",
      starts_at: time,
      ends_at: time
    )
    assert_not window.valid?
    assert_includes window.errors[:ends_at], "must be after starts_at"
  end

  # Scopes
  test "scope active returns only active windows" do
    active_windows = MaintenanceWindow.active
    active_windows.each do |window|
      assert window.active?, "Window #{window.name} should be active"
    end
  end

  test "scope current returns windows happening now" do
    current_windows = MaintenanceWindow.current
    current_windows.each do |window|
      assert window.starts_at <= Time.current
      assert window.ends_at >= Time.current
    end
  end

  test "scope for_project filters by project" do
    project = projects(:acme)
    project_windows = MaintenanceWindow.for_project(project.id)
    project_windows.each do |window|
      assert_equal project.id, window.project_id
    end
  end

  # Currently active
  test "currently_active? returns true for active window in time range" do
    window = maintenance_windows(:active_window)
    assert window.currently_active?
  end

  test "currently_active? returns false for inactive window" do
    window = maintenance_windows(:inactive_window)
    assert_not window.currently_active?
  end

  test "currently_active? returns false for past window" do
    window = maintenance_windows(:past_window)
    assert_not window.currently_active?
  end

  test "currently_active? returns false for future window" do
    window = maintenance_windows(:future_window)
    assert_not window.currently_active?
  end

  # Rule coverage
  test "covers_rule? returns true when rule_ids is empty" do
    project = projects(:acme)
    window = MaintenanceWindow.create!(
      project_id: project.id,
      name: "All Rules",
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      rule_ids: []
    )
    assert window.covers_rule?("any_rule_id")
    assert window.covers_rule?(nil)
  end

  test "covers_rule? returns true when rule is in rule_ids" do
    window = maintenance_windows(:future_window)
    rule_id = window.rule_ids.first
    assert window.covers_rule?(rule_id)
  end

  test "covers_rule? returns false when rule is not in rule_ids" do
    project = projects(:acme)
    window = MaintenanceWindow.create!(
      project: project,
      name: "Specific Rules Window",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now,
      rule_ids: [SecureRandom.uuid]  # specific rule_id
    )
    assert_not window.covers_rule?("non_existent_rule_id")
  end

  test "covers_rule? returns true when rule_ids is empty (covers all)" do
    window = maintenance_windows(:future_window)
    assert window.covers_rule?("any_rule_id")
  end

  # Defaults
  test "should default active to true" do
    project = projects(:acme)
    window = MaintenanceWindow.create!(
      project_id: project.id,
      name: "Default Test",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now
    )
    assert window.active?
  end

  test "should default recurring to false" do
    project = projects(:acme)
    window = MaintenanceWindow.create!(
      project_id: project.id,
      name: "Default Test",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now
    )
    assert_not window.recurring?
  end

  test "should default rule_ids to empty array" do
    project = projects(:acme)
    window = MaintenanceWindow.create!(
      project_id: project.id,
      name: "Default Test",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now
    )
    assert_equal [], window.rule_ids
  end

  test "should default services to empty array" do
    project = projects(:acme)
    window = MaintenanceWindow.create!(
      project_id: project.id,
      name: "Default Test",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now
    )
    assert_equal [], window.services
  end

  # Services filtering
  test "services can store array of service names" do
    project = projects(:acme)
    services = %w[api database cache]
    window = MaintenanceWindow.create!(
      project_id: project.id,
      name: "Service Maintenance",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now,
      services: services
    )
    assert_equal services, window.services
  end

  # Rule IDs filtering
  test "rule_ids can store array of rule UUIDs" do
    project = projects(:acme)
    rule_ids = [ alert_rules(:cpu_threshold).id, alert_rules(:error_rate).id ]
    window = MaintenanceWindow.create!(
      project_id: project.id,
      name: "Specific Rules",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now,
      rule_ids: rule_ids
    )
    assert_equal rule_ids, window.rule_ids
  end

  # Recurring windows
  test "can configure recurring window" do
    project = projects(:acme)
    window = MaintenanceWindow.create!(
      project_id: project.id,
      name: "Weekly Maintenance",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now,
      recurring: true,
      recurrence_rule: "FREQ=WEEKLY;BYDAY=SU"
    )
    assert window.recurring?
    assert_equal "FREQ=WEEKLY;BYDAY=SU", window.recurrence_rule
  end

  # Created by tracking
  test "can track who created the window" do
    project = projects(:acme)
    window = MaintenanceWindow.create!(
      project_id: project.id,
      name: "Test",
      starts_at: 1.hour.from_now,
      ends_at: 2.hours.from_now,
      created_by: "admin@example.com"
    )
    assert_equal "admin@example.com", window.created_by
  end

  # Fixtures
  test "active_window fixture is currently active" do
    window = maintenance_windows(:active_window)
    assert window.valid?
    assert window.currently_active?
  end

  test "future_window fixture is not currently active" do
    window = maintenance_windows(:future_window)
    assert window.valid?
    assert_not window.currently_active?
    assert window.starts_at > Time.current
  end

  test "past_window fixture is not currently active" do
    window = maintenance_windows(:past_window)
    assert window.valid?
    assert_not window.currently_active?
    assert window.ends_at < Time.current
  end

  test "inactive_window fixture is not currently active" do
    window = maintenance_windows(:inactive_window)
    assert window.valid?
    assert_not window.currently_active?
    assert_not window.active?
  end
end
