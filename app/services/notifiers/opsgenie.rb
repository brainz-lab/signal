module Notifiers
  class Opsgenie < Base
    ALERTS_API = 'https://api.opsgenie.com/v2/alerts'.freeze

    protected

    def deliver!(payload)
      headers = {
        'Authorization' => "GenieKey #{@config[:api_key]}",
        'Content-Type' => 'application/json'
      }

      response = HTTP.headers(headers).post(ALERTS_API, json: payload)
      raise "Opsgenie error: #{response.body}" unless response.status.success?
      JSON.parse(response.body)
    end

    def build_payload(alert, notification_type)
      rule = alert.alert_rule

      priority = case rule.severity
                 when 'critical' then 'P1'
                 when 'warning' then 'P3'
                 else 'P5'
                 end

      {
        message: "[#{rule.severity.upcase}] #{rule.name}",
        alias: alert.fingerprint,
        description: rule.condition_description,
        priority: priority,
        source: 'Brainz Lab Signal',
        tags: [rule.source, rule.severity],
        details: {
          rule_id: rule.id,
          current_value: alert.current_value,
          threshold: alert.threshold_value,
          duration: alert.duration_human
        }
      }
    end

    def build_test_payload
      {
        message: 'Test alert from Brainz Lab Signal',
        alias: "test-#{SecureRandom.hex(8)}",
        description: 'This is a test alert',
        priority: 'P5',
        source: 'Brainz Lab Signal',
        tags: ['test']
      }
    end
  end
end
