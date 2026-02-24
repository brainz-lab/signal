class NotificationJob < ApplicationJob
  queue_as :notifications
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(channel_id:, alert_id:, notification_type:)
    channel = NotificationChannel.find(channel_id)
    alert = Alert.find(alert_id)

    return unless channel.enabled?
    return if alert.alert_rule.muted?

    # Check maintenance windows
    return if in_maintenance_window?(alert)

    # Check rate limits
    limiter = NotificationRateLimiter.new(
      project: alert.project,
      channel: channel,
      rule: alert.alert_rule
    )
    reason = limiter.check_limits
    if reason
      Notification.create!(
        project: alert.project,
        alert: alert,
        notification_channel: channel,
        notification_type: notification_type,
        status: "skipped",
        error_message: reason
      )
      return
    end

    channel.send_notification!(
      alert: alert,
      notification_type: notification_type.to_sym
    )
  end

  private

  def in_maintenance_window?(alert)
    MaintenanceWindow
      .for_project(alert.project_id)
      .active
      .current
      .any? { |window| window.covers_rule?(alert.alert_rule_id) }
  end
end
