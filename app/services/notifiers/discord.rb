module Notifiers
  class Discord < Base
    protected

    def deliver!(payload)
      response = HTTP.post(@config[:webhook_url], json: payload)
      raise "Discord error: #{response.body}" unless response.status.success?
      { status: response.status.code }
    end

    def build_payload(alert, notification_type)
      rule = alert.alert_rule

      color = case rule.severity
              when 'critical' then 16711680  # Red
              when 'warning' then 16744192   # Orange
              else 3586427                   # Blue
              end

      status_emoji = notification_type == :alert_fired ? '🔴' : '🟢'
      status_text = notification_type == :alert_fired ? 'FIRING' : 'RESOLVED'

      {
        username: 'Brainz Lab Signal',
        embeds: [{
          title: "#{status_emoji} [#{status_text}] #{rule.name}",
          description: rule.condition_description,
          color: color,
          fields: [
            { name: 'Severity', value: rule.severity.upcase, inline: true },
            { name: 'Value', value: alert.current_value.to_s, inline: true },
            { name: 'Duration', value: alert.duration_human, inline: true },
            { name: 'Source', value: "#{rule.source}/#{rule.source_name}", inline: true }
          ],
          footer: { text: 'Brainz Lab Signal' },
          timestamp: Time.current.iso8601
        }]
      }
    end

    def build_test_payload
      {
        username: 'Brainz Lab Signal',
        content: 'Test notification from Brainz Lab Signal. Your Discord integration is working!'
      }
    end
  end
end
