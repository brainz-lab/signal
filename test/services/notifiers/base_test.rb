# frozen_string_literal: true

require "test_helper"

class Notifiers::BaseTest < ActiveSupport::TestCase
  setup do
    project = projects(:acme)
    @channel = NotificationChannel.create!(
      project: project,
      name: "Base Test Channel",
      channel_type: "slack",
      config: { webhook_url: "https://hooks.slack.com/services/test" }
    )
    rule = alert_rules(:cpu_threshold)
    @alert = rule.alerts.create!(
      project: project,
      fingerprint: "base_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current,
      current_value: 95.0
    )
  end

  # Since Base is abstract, we'll test through a concrete implementation
  # but focus on the shared Base behavior

  # Test concrete notifier for Base behavior
  class TestNotifier < Notifiers::Base
    attr_accessor :should_fail, :test_response

    def initialize(channel)
      super
      @should_fail = false
      @test_response = { status: 200 }
    end

    protected

    def deliver!(payload)
      raise "Test error" if @should_fail
      @test_response
    end

    def build_payload(alert, notification_type)
      { alert_id: alert.id, type: notification_type }
    end

    def build_test_payload
      { test: true }
    end
  end

  # Initialization
  test "initializes with channel" do
    notifier = TestNotifier.new(@channel)
    assert_not_nil notifier
  end

  # send! success
  test "send! returns success on successful delivery" do
    notifier = TestNotifier.new(@channel)

    result = notifier.send!(alert: @alert, notification_type: :alert_fired)

    assert result[:success]
    assert_not_nil result[:response]
  end

  test "send! increments success_count on success" do
    notifier = TestNotifier.new(@channel)
    original_count = @channel.success_count

    notifier.send!(alert: @alert, notification_type: :alert_fired)
    @channel.reload

    assert_equal original_count + 1, @channel.success_count
  end

  test "send! updates last_used_at on success" do
    notifier = TestNotifier.new(@channel)

    notifier.send!(alert: @alert, notification_type: :alert_fired)
    @channel.reload

    assert_not_nil @channel.last_used_at
    assert @channel.last_used_at > 1.minute.ago
  end

  test "send! creates sent notification record on success" do
    notifier = TestNotifier.new(@channel)

    assert_difference "Notification.count", 1 do
      notifier.send!(alert: @alert, notification_type: :alert_fired)
    end

    notification = Notification.where(notification_channel_id: @channel.id).last
    assert_equal "sent", notification.status
    assert_equal @alert.id, notification.alert_id
    assert_equal @channel.id, notification.notification_channel_id
    assert_equal "alert_fired", notification.notification_type
    assert_not_nil notification.sent_at
  end

  # send! failure
  test "send! returns failure on error" do
    notifier = TestNotifier.new(@channel)
    notifier.should_fail = true

    result = notifier.send!(alert: @alert, notification_type: :alert_fired)

    assert_not result[:success]
    assert_not_nil result[:error]
  end

  test "send! increments failure_count on error" do
    notifier = TestNotifier.new(@channel)
    notifier.should_fail = true
    original_count = @channel.failure_count

    notifier.send!(alert: @alert, notification_type: :alert_fired)
    @channel.reload

    assert_equal original_count + 1, @channel.failure_count
  end

  test "send! creates failed notification record on error" do
    notifier = TestNotifier.new(@channel)
    notifier.should_fail = true

    assert_difference "Notification.count", 1 do
      notifier.send!(alert: @alert, notification_type: :alert_fired)
    end

    notification = Notification.where(notification_channel_id: @channel.id).last
    assert_equal "failed", notification.status
    assert_not_nil notification.error_message
    assert_equal "Test error", notification.error_message
  end

  # test!
  test "test! returns success on successful delivery" do
    notifier = TestNotifier.new(@channel)

    result = notifier.test!

    assert result[:success]
  end

  test "test! returns failure on error" do
    notifier = TestNotifier.new(@channel)
    notifier.should_fail = true

    result = notifier.test!

    assert_not result[:success]
    assert_not_nil result[:error]
  end

  test "test! does not create notification record" do
    notifier = TestNotifier.new(@channel)

    assert_no_difference "Notification.count" do
      notifier.test!
    end
  end

  test "test! does not update channel counts" do
    notifier = TestNotifier.new(@channel)
    original_success = @channel.success_count
    original_failure = @channel.failure_count

    notifier.test!
    @channel.reload

    assert_equal original_success, @channel.success_count
    assert_equal original_failure, @channel.failure_count
  end

  # Notification record content
  test "notification record includes payload" do
    notifier = TestNotifier.new(@channel)

    notifier.send!(alert: @alert, notification_type: :alert_fired)

    notification = Notification.where(notification_channel_id: @channel.id).last
    assert notification.payload.is_a?(Hash)
    assert_equal @alert.id, notification.payload["alert_id"]
  end

  test "notification record includes response on success" do
    notifier = TestNotifier.new(@channel)

    notifier.send!(alert: @alert, notification_type: :alert_fired)

    notification = Notification.where(notification_channel_id: @channel.id).last
    assert notification.response.is_a?(Hash)
  end

  test "notification record includes project_id" do
    notifier = TestNotifier.new(@channel)

    notifier.send!(alert: @alert, notification_type: :alert_fired)

    notification = Notification.where(notification_channel_id: @channel.id).last
    assert_equal @channel.project_id, notification.project_id
  end
end
