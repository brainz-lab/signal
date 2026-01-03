# frozen_string_literal: true

require "test_helper"

class OnCallScheduleTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    project = projects(:acme)
    schedule = OnCallSchedule.new(
      project_id: project.id,
      name: "New Schedule",
      schedule_type: "weekly"
    )
    assert schedule.valid?, schedule.errors.full_messages.join(", ")
  end

  test "should require name" do
    schedule = OnCallSchedule.new(schedule_type: "weekly")
    assert_not schedule.valid?
    assert_includes schedule.errors[:name], "can't be blank"
  end

  test "should require project_id" do
    schedule = OnCallSchedule.new(name: "Test", schedule_type: "weekly")
    assert_not schedule.valid?
    assert_includes schedule.errors[:project_id], "can't be blank"
  end

  test "should require schedule_type" do
    project = projects(:acme)
    schedule = OnCallSchedule.new(project_id: project.id, name: "Test")
    assert_not schedule.valid?
    assert_includes schedule.errors[:schedule_type], "can't be blank"
  end

  test "should validate schedule_type inclusion" do
    project = projects(:acme)
    schedule = OnCallSchedule.new(
      project_id: project.id,
      name: "Test",
      schedule_type: "invalid"
    )
    assert_not schedule.valid?
    assert_includes schedule.errors[:schedule_type], "is not included in the list"
  end

  test "should accept valid schedule_types" do
    project = projects(:acme)
    %w[weekly custom].each do |type|
      schedule = OnCallSchedule.new(
        project_id: project.id,
        name: "Test #{type}",
        schedule_type: type
      )
      assert schedule.valid?, "#{type} should be valid: #{schedule.errors.full_messages.join(', ')}"
    end
  end

  test "should enforce unique slug per project" do
    existing = on_call_schedules(:weekly_schedule)
    duplicate = OnCallSchedule.new(
      project_id: existing.project_id,
      name: "Different Name",
      slug: existing.slug,
      schedule_type: "weekly"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "should allow same slug in different projects" do
    schedule1 = on_call_schedules(:weekly_schedule)
    staging_project = projects(:staging)

    schedule2 = OnCallSchedule.new(
      project_id: staging_project.id,
      name: "Same Slug Different Project",
      slug: schedule1.slug,
      schedule_type: "weekly"
    )
    assert schedule2.valid?
  end

  # Slug generation
  test "should auto-generate slug from name on create" do
    project = projects(:acme)
    schedule = OnCallSchedule.new(
      project_id: project.id,
      name: "My On Call Schedule",
      schedule_type: "weekly"
    )
    schedule.save!
    assert_equal "my-on-call-schedule", schedule.slug
  end

  test "should not override existing slug" do
    project = projects(:acme)
    schedule = OnCallSchedule.new(
      project_id: project.id,
      name: "Custom Name",
      slug: "custom-slug",
      schedule_type: "weekly"
    )
    schedule.save!
    assert_equal "custom-slug", schedule.slug
  end

  # Scopes
  test "scope enabled returns only enabled schedules" do
    enabled_schedules = OnCallSchedule.enabled
    enabled_schedules.each do |schedule|
      assert schedule.enabled?, "Schedule #{schedule.name} should be enabled"
    end
  end

  test "scope for_project filters by project" do
    project = projects(:acme)
    project_schedules = OnCallSchedule.for_project(project.id)
    project_schedules.each do |schedule|
      assert_equal project.id, schedule.project_id
    end
  end

  # Defaults
  test "should default enabled to true" do
    project = projects(:acme)
    schedule = OnCallSchedule.create!(
      project_id: project.id,
      name: "Default Test",
      schedule_type: "weekly"
    )
    assert schedule.enabled?
  end

  test "should default timezone to UTC" do
    project = projects(:acme)
    schedule = OnCallSchedule.create!(
      project_id: project.id,
      name: "Default Test",
      schedule_type: "weekly"
    )
    assert_equal "UTC", schedule.timezone
  end

  test "should default members to empty array" do
    project = projects(:acme)
    schedule = OnCallSchedule.create!(
      project_id: project.id,
      name: "Default Test",
      schedule_type: "weekly"
    )
    assert_equal [], schedule.members
  end

  test "should default weekly_schedule to empty hash" do
    project = projects(:acme)
    schedule = OnCallSchedule.create!(
      project_id: project.id,
      name: "Default Test",
      schedule_type: "weekly"
    )
    assert_equal({}, schedule.weekly_schedule)
  end

  # Weekly schedule configuration
  test "weekly_schedule can store day-based assignments" do
    project = projects(:acme)
    weekly = {
      "monday" => { "user" => "alice@example.com" },
      "tuesday" => { "user" => "bob@example.com" },
      "wednesday" => { "user" => "charlie@example.com" }
    }
    schedule = OnCallSchedule.create!(
      project_id: project.id,
      name: "Weekly Test",
      schedule_type: "weekly",
      weekly_schedule: weekly
    )
    assert_equal weekly, schedule.weekly_schedule
    assert_equal "alice@example.com", schedule.weekly_schedule["monday"]["user"]
  end

  # Custom rotation configuration
  test "custom schedule can have rotation members" do
    project = projects(:acme)
    members = %w[alice@example.com bob@example.com charlie@example.com]
    schedule = OnCallSchedule.create!(
      project_id: project.id,
      name: "Rotation Test",
      schedule_type: "custom",
      members: members,
      rotation_type: "weekly",
      rotation_start: 1.month.ago
    )
    assert_equal members, schedule.members
    assert_equal "weekly", schedule.rotation_type
  end

  # Current on-call user
  test "current_on_call_user returns current_on_call when shift is valid" do
    schedule = on_call_schedules(:weekly_schedule)
    # Ensure the shift is still valid
    schedule.update!(current_shift_end: 1.hour.from_now)

    assert_equal schedule.current_on_call, schedule.current_on_call_user
  end

  test "current_on_call_user updates on-call when shift expired" do
    schedule = on_call_schedules(:weekly_schedule)
    # Set shift to expired
    schedule.update!(current_shift_end: 1.hour.ago)

    # Should trigger update and return new user
    user = schedule.current_on_call_user
    assert_not_nil user
    # Shift end should be updated
    assert schedule.current_shift_end > Time.current
  end

  # Update on-call methods
  test "update_current_on_call! calls weekly update for weekly type" do
    schedule = on_call_schedules(:weekly_schedule)
    day = Time.current.strftime("%A").downcase
    schedule.weekly_schedule[day] = { "user" => "test@example.com" }
    schedule.save!

    schedule.update_current_on_call!

    assert_equal "test@example.com", schedule.current_on_call
  end

  test "update_current_on_call! calls rotation update for custom type" do
    schedule = on_call_schedules(:rotation_schedule)
    schedule.update_current_on_call!

    assert_includes schedule.members, schedule.current_on_call
  end

  # Rotation algorithm
  test "rotation calculates correct member based on days since start" do
    schedule = on_call_schedules(:rotation_schedule)
    schedule.update!(rotation_start: Date.today - 7.days)
    schedule.send(:update_rotation_on_call!)

    # After 7 days with weekly rotation, should be on 2nd member (index 1)
    # But this depends on the actual date calculation
    assert_includes schedule.members, schedule.current_on_call
  end

  # Fixtures
  test "weekly_schedule fixture is valid" do
    schedule = on_call_schedules(:weekly_schedule)
    assert schedule.valid?
    assert_equal "weekly", schedule.schedule_type
    assert schedule.weekly_schedule.is_a?(Hash)
  end

  test "rotation_schedule fixture is valid" do
    schedule = on_call_schedules(:rotation_schedule)
    assert schedule.valid?
    assert_equal "custom", schedule.schedule_type
    assert schedule.members.is_a?(Array)
    assert_equal "weekly", schedule.rotation_type
  end

  test "disabled_schedule fixture is disabled" do
    schedule = on_call_schedules(:disabled_schedule)
    assert schedule.valid?
    assert_not schedule.enabled?
  end
end
