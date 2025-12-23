module Notifiers
  class Slack < Base
    protected

    def deliver!(payload)
      response = HTTP.post(@config[:webhook_url], json: payload)
      raise "Slack error: #{response.body}" unless response.status.success?
      { status: response.status.code }
    end

    def build_payload(alert, notification_type)
      rule = alert.alert_rule

      color = case rule.severity
              when 'critical' then '#FF0000'
              when 'warning' then '#FFA500'
              else '#36A2EB'
              end

      status_emoji = notification_type == :alert_fired ? '🔴' : '🟢'
      status_text = notification_type == :alert_fired ? 'FIRING' : 'RESOLVED'

      {
        channel: @config[:channel],
        username: 'Brainz Lab Signal',
        icon_emoji: ':bell:',
        attachments: [{
          color: color,
          title: "#{status_emoji} [#{status_text}] #{rule.name}",
          text: rule.condition_description,
          fields: [
            { title: 'Severity', value: rule.severity.upcase, short: true },
            { title: 'Value', value: alert.current_value.to_s, short: true },
            { title: 'Duration', value: alert.duration_human, short: true },
            { title: 'Source', value: "#{rule.source}/#{rule.source_name}", short: true }
          ],
          footer: 'Brainz Lab Signal',
          ts: Time.current.to_i,
          actions: [
            {
              type: 'button',
              text: 'View Alert',
              url: alert_url(alert)
            },
            {
              type: 'button',
              text: 'Acknowledge',
              url: acknowledge_url(alert)
            }
          ]
        }]
      }
    end

    def build_test_payload
      {
        channel: @config[:channel],
        username: 'Brainz Lab Signal',
        icon_emoji: ':bell:',
        text: 'Test notification from Brainz Lab Signal. Your Slack integration is working!'
      }
    end

    private

    def alert_url(alert)
      base_url = ENV.fetch('SIGNAL_URL', 'https://signal.brainzlab.ai')
      "#{base_url}/alerts/#{alert.id}"
    end

    def acknowledge_url(alert)
      "#{alert_url(alert)}/acknowledge"
    end
  end
end
