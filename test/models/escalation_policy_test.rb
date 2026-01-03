# frozen_string_literal: true

require "test_helper"

class EscalationPolicyTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    project = projects(:acme)
    policy = EscalationPolicy.new(
      project_id: project.id,
      name: "New Policy"
    )
    assert policy.valid?, policy.errors.full_messages.join(", ")
  end

  test "should require name" do
    policy = EscalationPolicy.new
    assert_not policy.valid?
    assert_includes policy.errors[:name], "can't be blank"
  end

  test "should require project_id" do
    policy = EscalationPolicy.new(name: "Test")
    assert_not policy.valid?
    assert_includes policy.errors[:project_id], "can't be blank"
  end

  test "should enforce unique slug per project" do
    existing = escalation_policies(:default_policy)
    duplicate = EscalationPolicy.new(
      project_id: existing.project_id,
      name: "Different Name",
      slug: existing.slug
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "should allow same slug in different projects" do
    policy1 = escalation_policies(:default_policy)
    staging_project = projects(:staging)

    policy2 = EscalationPolicy.new(
      project_id: staging_project.id,
      name: "Same Slug Different Project",
      slug: policy1.slug
    )
    assert policy2.valid?
  end

  # Slug generation
  test "should auto-generate slug from name on create" do
    project = projects(:acme)
    policy = EscalationPolicy.new(
      project_id: project.id,
      name: "My Escalation Policy"
    )
    policy.save!
    assert_equal "my-escalation-policy", policy.slug
  end

  test "should not override existing slug" do
    project = projects(:acme)
    policy = EscalationPolicy.new(
      project_id: project.id,
      name: "Custom Name",
      slug: "custom-slug"
    )
    policy.save!
    assert_equal "custom-slug", policy.slug
  end

  # Associations
  test "should have many alert_rules" do
    policy = escalation_policies(:default_policy)
    assert_respond_to policy, :alert_rules
  end

  test "alert_rules are nullified when policy is destroyed" do
    policy = escalation_policies(:default_policy)
    rule = alert_rules(:cpu_threshold)
    rule.update!(escalation_policy: policy)

    policy.destroy
    rule.reload

    assert_nil rule.escalation_policy_id
  end

  # Scopes
  test "scope enabled returns only enabled policies" do
    enabled_policies = EscalationPolicy.enabled
    enabled_policies.each do |policy|
      assert policy.enabled?, "Policy #{policy.name} should be enabled"
    end
  end

  test "scope for_project filters by project" do
    project = projects(:acme)
    project_policies = EscalationPolicy.for_project(project.id)
    project_policies.each do |policy|
      assert_equal project.id, policy.project_id
    end
  end

  # Defaults
  test "should default enabled to true" do
    project = projects(:acme)
    policy = EscalationPolicy.create!(
      project_id: project.id,
      name: "Default Test"
    )
    assert policy.enabled?
  end

  test "should default repeat to false" do
    project = projects(:acme)
    policy = EscalationPolicy.create!(
      project_id: project.id,
      name: "Default Test"
    )
    assert_not policy.repeat?
  end

  test "should default steps to empty array" do
    project = projects(:acme)
    policy = EscalationPolicy.create!(
      project_id: project.id,
      name: "Default Test"
    )
    assert_equal [], policy.steps
  end

  # Steps configuration
  test "steps can store escalation configuration" do
    project = projects(:acme)
    steps = [
      { "delay_minutes" => 0, "notify" => [ { "channel_id" => "abc123" } ] },
      { "delay_minutes" => 15, "notify" => [ { "channel_id" => "def456" } ] }
    ]
    policy = EscalationPolicy.create!(
      project_id: project.id,
      name: "Steps Test",
      steps: steps
    )
    assert_equal steps, policy.steps
    assert_equal 2, policy.steps.size
  end

  # Repeat configuration
  test "can configure repeat settings" do
    project = projects(:acme)
    policy = EscalationPolicy.create!(
      project_id: project.id,
      name: "Repeat Test",
      repeat: true,
      repeat_after_minutes: 30,
      max_repeats: 3
    )
    assert policy.repeat?
    assert_equal 30, policy.repeat_after_minutes
    assert_equal 3, policy.max_repeats
  end

  # Fixtures
  test "default_policy fixture is valid" do
    policy = escalation_policies(:default_policy)
    assert policy.valid?
    assert policy.enabled?
    assert_not policy.repeat?
    assert policy.steps.is_a?(Array)
  end

  test "critical_policy fixture has repeat enabled" do
    policy = escalation_policies(:critical_policy)
    assert policy.valid?
    assert policy.repeat?
    assert_not_nil policy.repeat_after_minutes
    assert_not_nil policy.max_repeats
  end

  test "disabled_policy fixture is disabled" do
    policy = escalation_policies(:disabled_policy)
    assert policy.valid?
    assert_not policy.enabled?
  end
end
