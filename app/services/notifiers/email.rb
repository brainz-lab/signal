module Notifiers
  class Email < Base
    protected

    def deliver!(payload)
      AlertMailer.alert_notification(
        to: @config[:to],
        subject: payload[:subject],
        body: payload[:body],
        alert_id: payload[:alert_id]
      ).deliver_now

      { delivered: true }
    end

    def build_payload(alert, notification_type)
      rule = alert.alert_rule
      status = notification_type == :alert_fired ? 'FIRING' : 'RESOLVED'

      subject_prefix = @config[:subject_prefix] || '[Brainz Lab Signal]'

      {
        subject: "#{subject_prefix} [#{status}] #{rule.name}",
        body: build_email_body(alert, notification_type),
        alert_id: alert.id
      }
    end

    def build_test_payload
      {
        subject: '[Brainz Lab Signal] Test Notification',
        body: 'This is a test notification from Brainz Lab Signal. Your email integration is working!',
        alert_id: nil
      }
    end

    private

    def build_email_body(alert, notification_type)
      rule = alert.alert_rule
      status = notification_type == :alert_fired ? 'FIRING' : 'RESOLVED'
      base_url = ENV.fetch('SIGNAL_URL', 'https://signal.brainzlab.ai')

      <<~BODY
        Alert Status: #{status}

        Rule: #{rule.name}
        Severity: #{rule.severity.upcase}
        Condition: #{rule.condition_description}

        Current Value: #{alert.current_value}
        Threshold: #{alert.threshold_value}
        Duration: #{alert.duration_human}

        Started: #{alert.started_at}
        #{alert.resolved_at ? "Resolved: #{alert.resolved_at}" : ''}

        View Alert: #{base_url}/alerts/#{alert.id}

        ---
        Brainz Lab Signal
      BODY
    end
  end
end
