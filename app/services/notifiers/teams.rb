module Notifiers
  class Teams < Base
    protected

    def deliver!(payload)
      response = HTTP.post(@config[:webhook_url], json: payload)
      raise "Teams error: #{response.body}" unless response.status.success?
      { status: response.status.code }
    end

    def build_payload(alert, notification_type)
      rule = alert.alert_rule

      color = case rule.severity
      when "critical" then "FF0000"
      when "warning" then "FFA500"
      else "36A2EB"
      end

      status_emoji = notification_type == :alert_fired ? "🔴" : "🟢"
      status_text = notification_type == :alert_fired ? "FIRING" : "RESOLVED"

      {
        '@type': "MessageCard",
        '@context': "http://schema.org/extensions",
        themeColor: color,
        summary: "#{status_text}: #{rule.name}",
        sections: [ {
          activityTitle: "#{status_emoji} [#{status_text}] #{rule.name}",
          activitySubtitle: rule.condition_description,
          facts: [
            { name: "Severity", value: rule.severity.upcase },
            { name: "Value", value: alert.current_value.to_s },
            { name: "Duration", value: alert.duration_human },
            { name: "Source", value: "#{rule.source}/#{rule.source_name}" }
          ],
          markdown: true
        } ],
        potentialAction: [ {
          '@type': "OpenUri",
          name: "View Alert",
          targets: [ { os: "default", uri: alert_url(alert) } ]
        } ]
      }
    end

    def build_test_payload
      {
        '@type': "MessageCard",
        '@context': "http://schema.org/extensions",
        themeColor: "36A2EB",
        summary: "Test from Brainz Lab Signal",
        sections: [ {
          activityTitle: "Test Notification",
          activitySubtitle: "Your Microsoft Teams integration is working!"
        } ]
      }
    end

    private

    def alert_url(alert)
      base_url = ENV.fetch("SIGNAL_URL", "https://signal.brainzlab.ai")
      "#{base_url}/alerts/#{alert.id}"
    end
  end
end
