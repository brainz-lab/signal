class DigestJob < ApplicationJob
  queue_as :notifications

  def perform(project_id:, channel_id:, period: 'daily')
    channel = NotificationChannel.find(channel_id)
    return unless channel.enabled?

    # Get alerts from the period
    start_time = case period
                 when 'hourly' then 1.hour.ago
                 when 'daily' then 1.day.ago
                 when 'weekly' then 1.week.ago
                 else 1.day.ago
                 end

    alerts = Alert.for_project(project_id)
      .where('started_at > ?', start_time)
      .includes(:alert_rule)
      .order(started_at: :desc)

    return if alerts.empty?

    # Build digest payload
    payload = build_digest_payload(alerts, period)

    # Send via channel's notifier
    channel.notifier.deliver!(payload)
  end

  private

  def build_digest_payload(alerts, period)
    firing_count = alerts.firing.count
    resolved_count = alerts.resolved.count
    critical_count = alerts.joins(:alert_rule).where(alert_rules: { severity: 'critical' }).count

    {
      text: "Alert Digest (#{period})",
      attachments: [{
        title: "Alert Summary",
        fields: [
          { title: 'Total Alerts', value: alerts.count.to_s, short: true },
          { title: 'Firing', value: firing_count.to_s, short: true },
          { title: 'Resolved', value: resolved_count.to_s, short: true },
          { title: 'Critical', value: critical_count.to_s, short: true }
        ],
        footer: "Brainz Lab Signal Digest"
      }]
    }
  end
end
