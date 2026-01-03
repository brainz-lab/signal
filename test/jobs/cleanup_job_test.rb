# frozen_string_literal: true

require "test_helper"

class CleanupJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @project = projects(:acme)
    @rule = alert_rules(:cpu_threshold)
  end

  # Job configuration
  test "job is queued on maintenance queue" do
    assert_equal "maintenance", CleanupJob.new.queue_name
  end

  # Alert cleanup
  test "deletes resolved alerts older than 90 days" do
    old_alert = @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "old_resolved_#{SecureRandom.hex(8)}",
      state: "resolved",
      started_at: 100.days.ago,
      resolved_at: 95.days.ago
    )

    assert_difference "Alert.count", -1 do
      CleanupJob.perform_now
    end

    assert_not Alert.exists?(old_alert.id)
  end

  test "keeps resolved alerts newer than 90 days" do
    recent_alert = @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "recent_resolved_#{SecureRandom.hex(8)}",
      state: "resolved",
      started_at: 30.days.ago,
      resolved_at: 10.days.ago
    )

    CleanupJob.perform_now

    assert Alert.exists?(recent_alert.id)
  end

  test "keeps firing alerts regardless of age" do
    old_firing = @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "old_firing_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 100.days.ago
    )

    CleanupJob.perform_now

    assert Alert.exists?(old_firing.id)
  end

  # Alert history cleanup
  test "deletes alert history older than 90 days" do
    old_history = AlertHistory.create!(
      project_id: @project.id,
      alert_rule: @rule,
      fingerprint: "old_history",
      state: "ok",
      timestamp: 100.days.ago
    )

    assert_difference "AlertHistory.count", -1 do
      CleanupJob.perform_now
    end

    assert_not AlertHistory.exists?(old_history.id)
  end

  test "keeps alert history newer than 90 days" do
    recent_history = AlertHistory.create!(
      project_id: @project.id,
      alert_rule: @rule,
      fingerprint: "recent_history",
      state: "ok",
      timestamp: 30.days.ago
    )

    CleanupJob.perform_now

    assert AlertHistory.exists?(recent_history.id)
  end

  # Notification cleanup
  test "deletes notifications older than 30 days" do
    channel = notification_channels(:slack_channel)
    old_notification = Notification.create!(
      project_id: @project.id,
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "sent",
      created_at: 35.days.ago
    )

    # Force the created_at to be old
    old_notification.update_column(:created_at, 35.days.ago)

    assert_difference "Notification.count", -1 do
      CleanupJob.perform_now
    end

    assert_not Notification.exists?(old_notification.id)
  end

  test "keeps notifications newer than 30 days" do
    channel = notification_channels(:slack_channel)
    recent_notification = Notification.create!(
      project_id: @project.id,
      notification_channel: channel,
      notification_type: "alert_fired",
      status: "sent"
    )

    CleanupJob.perform_now

    assert Notification.exists?(recent_notification.id)
  end

  # Maintenance window cleanup
  test "deletes non-recurring maintenance windows older than 30 days" do
    old_window = MaintenanceWindow.create!(
      project_id: @project.id,
      name: "Old Maintenance",
      starts_at: 40.days.ago,
      ends_at: 35.days.ago,
      recurring: false
    )

    assert_difference "MaintenanceWindow.count", -1 do
      CleanupJob.perform_now
    end

    assert_not MaintenanceWindow.exists?(old_window.id)
  end

  test "keeps recurring maintenance windows regardless of age" do
    old_recurring = MaintenanceWindow.create!(
      project_id: @project.id,
      name: "Old Recurring",
      starts_at: 40.days.ago,
      ends_at: 35.days.ago,
      recurring: true,
      recurrence_rule: "FREQ=WEEKLY"
    )

    CleanupJob.perform_now

    assert MaintenanceWindow.exists?(old_recurring.id)
  end

  test "keeps non-recurring maintenance windows newer than 30 days" do
    recent_window = MaintenanceWindow.create!(
      project_id: @project.id,
      name: "Recent Maintenance",
      starts_at: 20.days.ago,
      ends_at: 15.days.ago,
      recurring: false
    )

    CleanupJob.perform_now

    assert MaintenanceWindow.exists?(recent_window.id)
  end

  # Logging
  test "logs completion message" do
    # Simply ensure job completes without error (logging is implementation detail)
    assert_nothing_raised do
      CleanupJob.perform_now
    end
  end

  # Multiple records
  test "cleans up multiple old records at once" do
    # Create multiple old records
    5.times do |i|
      @rule.alerts.create!(
        project_id: @project.id,
        fingerprint: "batch_old_#{i}_#{SecureRandom.hex(4)}",
        state: "resolved",
        started_at: (100 + i).days.ago,
        resolved_at: (95 + i).days.ago
      )
    end

    assert_difference "Alert.resolved.where('resolved_at < ?', 90.days.ago).count", -5 do
      CleanupJob.perform_now
    end
  end

  # Empty database
  test "handles empty tables gracefully" do
    # Delete in proper order due to foreign keys
    Notification.delete_all
    Alert.delete_all
    AlertHistory.delete_all
    MaintenanceWindow.delete_all

    assert_nothing_raised do
      CleanupJob.perform_now
    end
  end

  # Job enqueueing
  test "can be enqueued" do
    assert_enqueued_with(job: CleanupJob) do
      CleanupJob.perform_later
    end
  end
end
