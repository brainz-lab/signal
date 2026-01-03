# frozen_string_literal: true

require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    project = Project.new(
      platform_project_id: SecureRandom.uuid,
      name: "New Project",
      environment: "live"
    )
    assert project.valid?
  end

  test "should require platform_project_id" do
    project = Project.new(name: "Test")
    assert_not project.valid?
    assert_includes project.errors[:platform_project_id], "can't be blank"
  end

  test "should enforce unique platform_project_id" do
    existing = projects(:acme)
    duplicate = Project.new(
      platform_project_id: existing.platform_project_id,
      name: "Duplicate"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:platform_project_id], "has already been taken"
  end

  # Associations
  test "should have many alert_rules" do
    project = projects(:acme)
    assert_respond_to project, :alert_rules
    assert project.alert_rules.count >= 0
  end

  test "should have many alerts" do
    project = projects(:acme)
    assert_respond_to project, :alerts
  end

  test "should have many incidents" do
    project = projects(:acme)
    assert_respond_to project, :incidents
  end

  test "should have many notification_channels" do
    project = projects(:acme)
    assert_respond_to project, :notification_channels
  end

  test "should have many escalation_policies" do
    project = projects(:acme)
    assert_respond_to project, :escalation_policies
  end

  test "should have many on_call_schedules" do
    project = projects(:acme)
    assert_respond_to project, :on_call_schedules
  end

  test "should have many maintenance_windows" do
    project = projects(:acme)
    assert_respond_to project, :maintenance_windows
  end

  test "should destroy associated alert_rules when destroyed" do
    project = create_project
    create_alert_rule(project: project)

    assert_difference "AlertRule.count", -1 do
      project.destroy
    end
  end

  # Class methods
  test "find_or_create_for_platform! creates new project" do
    new_uuid = SecureRandom.uuid
    assert_difference "Project.count", 1 do
      project = Project.find_or_create_for_platform!(
        platform_project_id: new_uuid,
        name: "Brand New",
        environment: "staging"
      )
      assert_equal new_uuid, project.platform_project_id
      assert_equal "Brand New", project.name
      assert_equal "staging", project.environment
    end
  end

  test "find_or_create_for_platform! finds existing project" do
    existing = projects(:acme)

    assert_no_difference "Project.count" do
      project = Project.find_or_create_for_platform!(
        platform_project_id: existing.platform_project_id,
        name: "Different Name"
      )
      assert_equal existing.id, project.id
      # Name should not change for existing record
      assert_equal existing.name, project.name
    end
  end

  # Environment defaults
  test "should default environment to live" do
    project = Project.new(platform_project_id: SecureRandom.uuid)
    project.save!
    assert_equal "live", project.environment
  end
end
