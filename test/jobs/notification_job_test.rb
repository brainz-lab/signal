# frozen_string_literal: true

require "test_helper"

class NotificationJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @channel = notification_channels(:slack_channel)
    @alert = alerts(:firing_alert)
  end

  # Job configuration
  test "job is queued on notifications queue" do
    assert_equal "notifications", NotificationJob.new.queue_name
  end

  # Successful notification
  test "sends notification when all conditions met" do
    NotificationChannel.any_instance.expects(:send_notification!).with(
      alert: @alert,
      notification_type: :alert_fired
    ).once

    NotificationJob.perform_now(
      channel_id: @channel.id,
      alert_id: @alert.id,
      notification_type: "alert_fired"
    )
  end

  # Channel disabled
  test "does not send when channel is disabled" do
    @channel.update!(enabled: false)
    NotificationChannel.any_instance.expects(:send_notification!).never

    NotificationJob.perform_now(
      channel_id: @channel.id,
      alert_id: @alert.id,
      notification_type: "alert_fired"
    )
  end

  # Rule muted
  test "does not send when rule is muted" do
    @alert.alert_rule.update!(muted: true)
    NotificationChannel.any_instance.expects(:send_notification!).never

    NotificationJob.perform_now(
      channel_id: @channel.id,
      alert_id: @alert.id,
      notification_type: "alert_fired"
    )
  end

  # Maintenance window
  test "does not send during active maintenance window covering rule" do
    # Create an active maintenance window
    MaintenanceWindow.create!(
      project_id: @alert.project_id,
      name: "Test Maintenance",
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      active: true,
      rule_ids: []  # Empty covers all rules
    )

    NotificationChannel.any_instance.expects(:send_notification!).never

    NotificationJob.perform_now(
      channel_id: @channel.id,
      alert_id: @alert.id,
      notification_type: "alert_fired"
    )
  end

  test "sends notification when maintenance window does not cover rule" do
    # Create maintenance window for different rules
    MaintenanceWindow.create!(
      project_id: @alert.project_id,
      name: "Test Maintenance",
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      active: true,
      rule_ids: [ "different-rule-id" ]
    )

    NotificationChannel.any_instance.expects(:send_notification!).once

    NotificationJob.perform_now(
      channel_id: @channel.id,
      alert_id: @alert.id,
      notification_type: "alert_fired"
    )
  end

  test "sends notification when maintenance window is inactive" do
    MaintenanceWindow.create!(
      project_id: @alert.project_id,
      name: "Inactive Maintenance",
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      active: false,
      rule_ids: []
    )

    NotificationChannel.any_instance.expects(:send_notification!).once

    NotificationJob.perform_now(
      channel_id: @channel.id,
      alert_id: @alert.id,
      notification_type: "alert_fired"
    )
  end

  test "sends notification when maintenance window is in past" do
    MaintenanceWindow.create!(
      project_id: @alert.project_id,
      name: "Past Maintenance",
      starts_at: 2.hours.ago,
      ends_at: 1.hour.ago,
      active: true,
      rule_ids: []
    )

    NotificationChannel.any_instance.expects(:send_notification!).once

    NotificationJob.perform_now(
      channel_id: @channel.id,
      alert_id: @alert.id,
      notification_type: "alert_fired"
    )
  end

  # Notification types
  test "handles alert_fired notification type" do
    NotificationChannel.any_instance.expects(:send_notification!).with(
      alert: @alert,
      notification_type: :alert_fired
    )

    NotificationJob.perform_now(
      channel_id: @channel.id,
      alert_id: @alert.id,
      notification_type: "alert_fired"
    )
  end

  test "handles alert_resolved notification type" do
    NotificationChannel.any_instance.expects(:send_notification!).with(
      alert: @alert,
      notification_type: :alert_resolved
    )

    NotificationJob.perform_now(
      channel_id: @channel.id,
      alert_id: @alert.id,
      notification_type: "alert_resolved"
    )
  end

  # Retry behavior
  test "retries on error" do
    assert_equal 5, NotificationJob.new.class.send(:retry_limit)
  end

  # Edge cases
  test "raises when channel not found" do
    assert_raises ActiveRecord::RecordNotFound do
      NotificationJob.perform_now(
        channel_id: "non-existent-uuid",
        alert_id: @alert.id,
        notification_type: "alert_fired"
      )
    end
  end

  test "raises when alert not found" do
    assert_raises ActiveRecord::RecordNotFound do
      NotificationJob.perform_now(
        channel_id: @channel.id,
        alert_id: "non-existent-uuid",
        notification_type: "alert_fired"
      )
    end
  end

  # Job enqueueing
  test "can be enqueued with keyword arguments" do
    assert_enqueued_with(job: NotificationJob) do
      NotificationJob.perform_later(
        channel_id: @channel.id,
        alert_id: @alert.id,
        notification_type: "alert_fired"
      )
    end
  end
end
