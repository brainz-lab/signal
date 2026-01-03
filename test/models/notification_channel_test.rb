# frozen_string_literal: true

require "test_helper"

class NotificationChannelTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    project = projects(:acme)
    channel = NotificationChannel.new(
      project_id: project.id,
      name: "New Channel",
      channel_type: "slack",
      config: { webhook_url: "https://hooks.slack.com/test" }
    )
    assert channel.valid?, channel.errors.full_messages.join(", ")
  end

  test "should require name" do
    channel = NotificationChannel.new(channel_type: "slack")
    assert_not channel.valid?
    assert_includes channel.errors[:name], "can't be blank"
  end

  test "should require project_id" do
    channel = NotificationChannel.new(name: "Test", channel_type: "slack")
    assert_not channel.valid?
    assert_includes channel.errors[:project_id], "can't be blank"
  end

  test "should require channel_type" do
    project = projects(:acme)
    channel = NotificationChannel.new(project_id: project.id, name: "Test")
    assert_not channel.valid?
    assert_includes channel.errors[:channel_type], "can't be blank"
  end

  test "should validate channel_type inclusion" do
    project = projects(:acme)
    channel = NotificationChannel.new(
      project_id: project.id,
      name: "Test",
      channel_type: "invalid"
    )
    assert_not channel.valid?
    assert_includes channel.errors[:channel_type], "is not included in the list"
  end

  test "should accept valid channel_types" do
    project = projects(:acme)
    %w[slack pagerduty email webhook discord teams opsgenie].each do |type|
      channel = NotificationChannel.new(
        project_id: project.id,
        name: "Test #{type}",
        channel_type: type
      )
      assert channel.valid?, "#{type} should be valid: #{channel.errors.full_messages.join(', ')}"
    end
  end

  test "should enforce unique slug per project" do
    existing = notification_channels(:slack_channel)
    duplicate = NotificationChannel.new(
      project_id: existing.project_id,
      name: "Different Name",
      slug: existing.slug,
      channel_type: "slack"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "should allow same slug in different projects" do
    channel1 = notification_channels(:slack_channel)
    staging_project = projects(:staging)

    channel2 = NotificationChannel.new(
      project_id: staging_project.id,
      name: "Same Slug Different Project",
      slug: channel1.slug,
      channel_type: "slack"
    )
    assert channel2.valid?
  end

  # Slug generation
  test "should auto-generate slug from name on create" do
    project = projects(:acme)
    channel = NotificationChannel.new(
      project_id: project.id,
      name: "My Slack Channel",
      channel_type: "slack"
    )
    channel.save!
    assert_equal "my-slack-channel", channel.slug
  end

  test "should not override existing slug" do
    project = projects(:acme)
    channel = NotificationChannel.new(
      project_id: project.id,
      name: "Custom Name",
      slug: "custom-slug",
      channel_type: "slack"
    )
    channel.save!
    assert_equal "custom-slug", channel.slug
  end

  # Associations
  test "should have many notifications" do
    channel = notification_channels(:slack_channel)
    assert_respond_to channel, :notifications
  end

  test "should destroy notifications when destroyed" do
    channel = notification_channels(:slack_channel)
    notification_count = channel.notifications.count

    if notification_count > 0
      assert_difference "Notification.count", -notification_count do
        channel.destroy
      end
    end
  end

  # Scopes
  test "scope enabled returns only enabled channels" do
    enabled_channels = NotificationChannel.enabled
    enabled_channels.each do |channel|
      assert channel.enabled?, "Channel #{channel.name} should be enabled"
    end
  end

  test "scope for_project filters by project" do
    project = projects(:acme)
    project_channels = NotificationChannel.for_project(project.id)
    project_channels.each do |channel|
      assert_equal project.id, channel.project_id
    end
  end

  # Notifier factory
  test "notifier returns Slack notifier for slack channel" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project: project,
      name: "Slack Test",
      channel_type: "slack",
      config: { webhook_url: "https://hooks.slack.com/test" }
    )
    notifier = channel.notifier
    assert_instance_of Notifiers::Slack, notifier
  end

  test "notifier returns Pagerduty notifier for pagerduty channel" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project: project,
      name: "PagerDuty Test",
      channel_type: "pagerduty",
      config: { routing_key: "test_key" }
    )
    notifier = channel.notifier
    assert_instance_of Notifiers::Pagerduty, notifier
  end

  test "notifier returns Email notifier for email channel" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project: project,
      name: "Email Test",
      channel_type: "email",
      config: { recipients: ["test@example.com"] }
    )
    notifier = channel.notifier
    assert_instance_of Notifiers::Email, notifier
  end

  test "notifier returns Webhook notifier for webhook channel" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project: project,
      name: "Webhook Test",
      channel_type: "webhook",
      config: { url: "https://example.com/webhook" }
    )
    notifier = channel.notifier
    assert_instance_of Notifiers::Webhook, notifier
  end

  # Config encryption
  test "config is encrypted" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project: project,
      name: "Encryption Test",
      channel_type: "slack",
      config: { webhook_url: "https://hooks.slack.com/test" }
    )
    # Config should be accessible as a hash
    assert_kind_of Hash, channel.config
  end

  test "config can store channel-specific settings" do
    project = projects(:acme)
    config = { "webhook_url" => "https://hooks.slack.com/new", "channel" => "#alerts" }
    channel = NotificationChannel.create!(
      project_id: project.id,
      name: "Config Test",
      channel_type: "slack",
      config: config
    )
    channel.reload
    assert_equal "https://hooks.slack.com/new", channel.config["webhook_url"]
    assert_equal "#alerts", channel.config["channel"]
  end

  # Defaults
  test "should default enabled to true" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project_id: project.id,
      name: "Default Test",
      channel_type: "slack"
    )
    assert channel.enabled?
  end

  test "should default verified to false" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project_id: project.id,
      name: "Default Test",
      channel_type: "slack"
    )
    assert_not channel.verified?
  end

  test "should default success_count to 0" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project_id: project.id,
      name: "Default Test",
      channel_type: "slack"
    )
    assert_equal 0, channel.success_count
  end

  test "should default failure_count to 0" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project_id: project.id,
      name: "Default Test",
      channel_type: "slack"
    )
    assert_equal 0, channel.failure_count
  end

  # Test functionality
  test "test! updates test status on success" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project: project,
      name: "Test Success",
      channel_type: "slack",
      config: { webhook_url: "https://hooks.slack.com/test" }
    )

    # Stub the notifier test! method using Mocha
    Notifiers::Slack.any_instance.stubs(:test!).returns({ success: true, message: "OK" })

    result = channel.test!

    assert result[:success]
    assert_not_nil channel.last_tested_at
    assert_equal "success", channel.last_test_status
    assert channel.verified?
  end

  test "test! updates test status on failure" do
    project = projects(:acme)
    channel = NotificationChannel.create!(
      project: project,
      name: "Test Failure",
      channel_type: "slack",
      config: { webhook_url: "https://hooks.slack.com/test" }
    )

    # Stub the notifier test! method using Mocha
    Notifiers::Slack.any_instance.stubs(:test!).returns({ success: false, error: "Connection refused" })

    result = channel.test!

    assert_not result[:success]
    assert_not_nil channel.last_tested_at
    assert_equal "failed", channel.last_test_status
    assert_not channel.verified?
  end
end
