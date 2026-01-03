# frozen_string_literal: true

require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  # Validations
  test "should be valid with valid attributes" do
    channel = notification_channels(:slack_channel)
    notification = Notification.new(
      project_id: channel.project_id,
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "pending"
    )
    assert notification.valid?, notification.errors.full_messages.join(", ")
  end

  test "should require notification_type" do
    channel = notification_channels(:slack_channel)
    notification = Notification.new(
      project_id: channel.project_id,
      notification_channel: channel,
      status: "pending"
    )
    assert_not notification.valid?
    assert_includes notification.errors[:notification_type], "can't be blank"
  end

  test "should require status" do
    channel = notification_channels(:slack_channel)
    notification = Notification.new(
      project_id: channel.project_id,
      notification_channel: channel,
      notification_type: "alert_fired"
    )
    assert_not notification.valid?
    assert_includes notification.errors[:status], "can't be blank"
  end

  test "should require project_id" do
    channel = notification_channels(:slack_channel)
    notification = Notification.new(
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "pending"
    )
    assert_not notification.valid?
    assert_includes notification.errors[:project_id], "can't be blank"
  end

  test "should validate status inclusion" do
    channel = notification_channels(:slack_channel)
    notification = Notification.new(
      project_id: channel.project_id,
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "invalid"
    )
    assert_not notification.valid?
    assert_includes notification.errors[:status], "is not included in the list"
  end

  test "should accept valid statuses" do
    channel = notification_channels(:slack_channel)
    %w[pending sent failed skipped].each do |status|
      notification = Notification.new(
        project_id: channel.project_id,
        notification_channel: channel,
        notification_type: "alert_fired",
        status: status
      )
      assert notification.valid?, "#{status} should be valid: #{notification.errors.full_messages.join(', ')}"
    end
  end

  # Associations
  test "should belong to notification_channel" do
    notification = notifications(:sent_notification)
    assert_not_nil notification.notification_channel
    assert_instance_of NotificationChannel, notification.notification_channel
  end

  test "should belong to alert optionally" do
    notification = notifications(:sent_notification)
    assert_respond_to notification, :alert
  end

  test "should belong to incident optionally" do
    notification = Notification.new(
      project_id: projects(:acme).id,
      notification_channel: notification_channels(:slack_channel),
      notification_type: "incident_triggered",
      status: "pending",
      incident: incidents(:active_incident)
    )
    assert notification.valid?
    assert_equal incidents(:active_incident), notification.incident
  end

  # Scopes
  test "scope pending returns only pending notifications" do
    pending_notifications = Notification.pending
    pending_notifications.each do |notification|
      assert_equal "pending", notification.status
    end
  end

  test "scope sent returns only sent notifications" do
    sent_notifications = Notification.sent
    sent_notifications.each do |notification|
      assert_equal "sent", notification.status
    end
  end

  test "scope failed returns only failed notifications" do
    failed_notifications = Notification.failed
    failed_notifications.each do |notification|
      assert_equal "failed", notification.status
    end
  end

  test "scope for_project filters by project" do
    project = projects(:acme)
    project_notifications = Notification.for_project(project.id)
    project_notifications.each do |notification|
      assert_equal project.id, notification.project_id
    end
  end

  # Payload
  test "payload defaults to empty hash" do
    channel = notification_channels(:slack_channel)
    notification = Notification.create!(
      project_id: channel.project_id,
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "pending"
    )
    assert_equal({}, notification.payload)
  end

  test "payload can store arbitrary data" do
    channel = notification_channels(:slack_channel)
    payload = { "message" => "Alert triggered", "severity" => "critical" }
    notification = Notification.create!(
      project_id: channel.project_id,
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "pending",
      payload: payload
    )
    assert_equal payload, notification.payload
  end

  # Response
  test "response defaults to empty hash" do
    channel = notification_channels(:slack_channel)
    notification = Notification.create!(
      project_id: channel.project_id,
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "pending"
    )
    assert_equal({}, notification.response)
  end

  test "response can store API response data" do
    channel = notification_channels(:slack_channel)
    response = { "ok" => true, "message_ts" => "1234567890.123456" }
    notification = Notification.create!(
      project_id: channel.project_id,
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "sent",
      sent_at: Time.current,
      response: response
    )
    assert_equal response, notification.response
  end

  # Retry tracking
  test "retry_count defaults to 0" do
    channel = notification_channels(:slack_channel)
    notification = Notification.create!(
      project_id: channel.project_id,
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "pending"
    )
    assert_equal 0, notification.retry_count
  end

  test "can track retry attempts" do
    notification = notifications(:failed_notification)
    assert notification.retry_count > 0
    assert_not_nil notification.next_retry_at
  end

  # Error tracking
  test "can store error message for failed notifications" do
    notification = notifications(:failed_notification)
    assert_not_nil notification.error_message
    assert_equal "Connection refused", notification.error_message
  end

  # Notification types
  test "accepts various notification types" do
    channel = notification_channels(:slack_channel)
    %w[alert_fired alert_resolved incident_triggered incident_resolved digest escalation].each do |type|
      notification = Notification.new(
        project_id: channel.project_id,
        notification_channel: channel,
        notification_type: type,
        status: "pending"
      )
      assert notification.valid?, "notification_type #{type} should be valid"
    end
  end
end
