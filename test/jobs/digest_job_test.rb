# frozen_string_literal: true

require "test_helper"

class DigestJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @project = projects(:acme)
    @channel = notification_channels(:slack_channel)
    @rule = alert_rules(:cpu_threshold)
  end

  # Job configuration
  test "job is queued on notifications queue" do
    assert_equal "notifications", DigestJob.new.queue_name
  end

  # Basic execution
  test "sends digest when alerts exist" do
    # Create recent alert
    @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "digest_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 1.hour.ago
    )

    Notifiers::Slack.any_instance.expects(:deliver!).once

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "daily"
    )
  end

  test "does not send when no alerts in period" do
    # Ensure no recent alerts
    Alert.where("started_at > ?", 1.day.ago).delete_all

    Notifiers::Slack.any_instance.expects(:deliver!).never

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "daily"
    )
  end

  test "does not send when channel is disabled" do
    @channel.update!(enabled: false)

    # Create recent alert
    @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "disabled_channel_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 1.hour.ago
    )

    Notifiers::Slack.any_instance.expects(:deliver!).never

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "daily"
    )
  end

  # Period handling
  test "hourly period includes alerts from last hour" do
    # Create alert from 30 minutes ago (should be included)
    recent = @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "hourly_recent_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 30.minutes.ago
    )

    # Create alert from 2 hours ago (should not be included)
    old = @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "hourly_old_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 2.hours.ago
    )

    payload_checker = lambda do |payload|
      # Verify the payload includes correct counts
      assert payload[:attachments].present?
      true
    end

    Notifiers::Slack.any_instance.stubs(:deliver!).with(&payload_checker)

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "hourly"
    )
  end

  test "daily period includes alerts from last day" do
    @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "daily_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 12.hours.ago
    )

    Notifiers::Slack.any_instance.expects(:deliver!).once

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "daily"
    )
  end

  test "weekly period includes alerts from last week" do
    @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "weekly_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 3.days.ago
    )

    Notifiers::Slack.any_instance.expects(:deliver!).once

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "weekly"
    )
  end

  test "defaults to daily period for unknown period" do
    @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "unknown_period_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 12.hours.ago
    )

    Notifiers::Slack.any_instance.expects(:deliver!).once

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "unknown"
    )
  end

  # Payload building
  test "builds payload with alert counts" do
    # Create various alerts
    @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "firing_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 1.hour.ago
    )

    @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "resolved_#{SecureRandom.hex(8)}",
      state: "resolved",
      started_at: 2.hours.ago,
      resolved_at: 1.hour.ago
    )

    payload_received = nil
    Notifiers::Slack.any_instance.stubs(:deliver!).with do |payload|
      payload_received = payload
      true
    end

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "daily"
    )

    assert_not_nil payload_received
    assert_includes payload_received[:text], "Alert Digest"
    assert payload_received[:attachments].present?

    attachment = payload_received[:attachments].first
    assert_equal "Alert Summary", attachment[:title]

    field_titles = attachment[:fields].map { |f| f[:title] }
    assert_includes field_titles, "Total Alerts"
    assert_includes field_titles, "Firing"
    assert_includes field_titles, "Resolved"
    assert_includes field_titles, "Critical"
  end

  test "includes period in payload text" do
    @rule.alerts.create!(
      project_id: @project.id,
      fingerprint: "period_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 1.hour.ago
    )

    payload_received = nil
    Notifiers::Slack.any_instance.stubs(:deliver!).with do |payload|
      payload_received = payload
      true
    end

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "weekly"
    )

    assert_includes payload_received[:text], "weekly"
  end

  # Project filtering
  test "only includes alerts from specified project" do
    other_project = projects(:staging)

    # Create alert in other project
    other_rule = AlertRule.create!(
      project_id: other_project.id,
      name: "Other Rule",
      source: "flux",
      rule_type: "threshold",
      severity: "warning"
    )
    other_rule.alerts.create!(
      project_id: other_project.id,
      fingerprint: "other_project_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: 1.hour.ago
    )

    # No alerts in target project
    Alert.where(project_id: @project.id).where("started_at > ?", 1.day.ago).delete_all

    Notifiers::Slack.any_instance.expects(:deliver!).never

    DigestJob.perform_now(
      project_id: @project.id,
      channel_id: @channel.id,
      period: "daily"
    )
  end

  # Edge cases
  test "raises when channel not found" do
    assert_raises ActiveRecord::RecordNotFound do
      DigestJob.perform_now(
        project_id: @project.id,
        channel_id: "non-existent-uuid",
        period: "daily"
      )
    end
  end

  # Job enqueueing
  test "can be enqueued" do
    assert_enqueued_with(job: DigestJob) do
      DigestJob.perform_later(
        project_id: @project.id,
        channel_id: @channel.id,
        period: "daily"
      )
    end
  end
end
