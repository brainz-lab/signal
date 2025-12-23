module Notifiers
  class Pagerduty < Base
    EVENTS_API = 'https://events.pagerduty.com/v2/enqueue'.freeze

    protected

    def deliver!(payload)
      response = HTTP.post(EVENTS_API, json: payload)
      raise "PagerDuty error: #{response.body}" unless response.status.success?
      JSON.parse(response.body)
    end

    def build_payload(alert, notification_type)
      rule = alert.alert_rule

      event_action = notification_type == :alert_fired ? 'trigger' : 'resolve'
      severity = @config.dig(:severity_map, rule.severity) || rule.severity

      {
        routing_key: @config[:routing_key],
        event_action: event_action,
        dedup_key: alert.fingerprint,
        payload: {
          summary: "[#{rule.severity.upcase}] #{rule.name}: #{rule.condition_description}",
          source: 'Brainz Lab Signal',
          severity: severity,
          timestamp: Time.current.iso8601,
          custom_details: {
            rule_id: rule.id,
            rule_name: rule.name,
            current_value: alert.current_value,
            threshold: alert.threshold_value,
            duration: alert.duration_human,
            labels: alert.labels
          }
        },
        links: [
          {
            href: alert_url(alert),
            text: 'View in Brainz Lab'
          }
        ]
      }
    end

    def build_test_payload
      {
        routing_key: @config[:routing_key],
        event_action: 'trigger',
        dedup_key: "test-#{SecureRandom.hex(8)}",
        payload: {
          summary: 'Test alert from Brainz Lab Signal',
          source: 'Brainz Lab Signal',
          severity: 'info',
          timestamp: Time.current.iso8601
        }
      }
    end

    private

    def alert_url(alert)
      base_url = ENV.fetch('SIGNAL_URL', 'https://signal.brainzlab.ai')
      "#{base_url}/alerts/#{alert.id}"
    end
  end
end
