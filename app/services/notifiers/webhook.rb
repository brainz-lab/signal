module Notifiers
  class Webhook < Base
    protected

    def deliver!(payload)
      method = (@config[:method] || 'POST').upcase
      headers = (@config[:headers] || {}).merge('Content-Type' => 'application/json')

      response = HTTP.headers(headers).send(method.downcase, @config[:url], json: payload)
      raise "Webhook error: #{response.status}" unless response.status.success?

      { status: response.status.code, body: response.body.to_s[0..500] }
    end

    def build_payload(alert, notification_type)
      rule = alert.alert_rule

      if @config[:template].present?
        # Custom template
        render_template(@config[:template], alert, notification_type)
      else
        # Default payload
        {
          event_type: notification_type.to_s,
          timestamp: Time.current.iso8601,
          alert: {
            id: alert.id,
            fingerprint: alert.fingerprint,
            state: alert.state,
            started_at: alert.started_at.iso8601,
            resolved_at: alert.resolved_at&.iso8601,
            current_value: alert.current_value,
            threshold_value: alert.threshold_value,
            duration_seconds: alert.duration.to_i,
            labels: alert.labels,
            acknowledged: alert.acknowledged
          },
          rule: {
            id: rule.id,
            name: rule.name,
            severity: rule.severity,
            source: rule.source,
            source_name: rule.source_name,
            condition: rule.condition_description
          },
          project_id: alert.project_id
        }
      end
    end

    def build_test_payload
      {
        event_type: 'test',
        timestamp: Time.current.iso8601,
        message: 'Test webhook from Brainz Lab Signal'
      }
    end

    private

    def render_template(template, alert, notification_type)
      rule = alert.alert_rule

      result = template.dup
      result.gsub!('{{alert.id}}', alert.id.to_s)
      result.gsub!('{{alert.state}}', alert.state)
      result.gsub!('{{alert.value}}', alert.current_value.to_s)
      result.gsub!('{{rule.name}}', rule.name)
      result.gsub!('{{rule.severity}}', rule.severity)
      result.gsub!('{{notification_type}}', notification_type.to_s)

      JSON.parse(result)
    end
  end
end
