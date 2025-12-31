module Notifiers
  class Base
    def initialize(channel)
      @channel = channel
      @config = channel.config.with_indifferent_access
    end

    def send!(alert:, notification_type:)
      payload = build_payload(alert, notification_type)

      begin
        response = deliver!(payload)
        record_success!(alert, notification_type, payload, response)
        { success: true, response: response }
      rescue => e
        record_failure!(alert, notification_type, payload, e)
        { success: false, error: e.message }
      end
    end

    def test!
      payload = build_test_payload

      begin
        response = deliver!(payload)
        { success: true, response: response }
      rescue => e
        { success: false, error: e.message }
      end
    end

    protected

    def deliver!(payload)
      raise NotImplementedError
    end

    def build_payload(alert, notification_type)
      raise NotImplementedError
    end

    def build_test_payload
      raise NotImplementedError
    end

    private

    def record_success!(alert, notification_type, payload, response)
      @channel.increment!(:success_count)
      @channel.update!(last_used_at: Time.current)

      Notification.create!(
        project_id: @channel.project_id,
        alert: alert,
        notification_channel: @channel,
        notification_type: notification_type.to_s,
        status: "sent",
        payload: payload,
        response: response,
        sent_at: Time.current
      )
    end

    def record_failure!(alert, notification_type, payload, error)
      @channel.increment!(:failure_count)

      Notification.create!(
        project_id: @channel.project_id,
        alert: alert,
        notification_channel: @channel,
        notification_type: notification_type.to_s,
        status: "failed",
        payload: payload,
        error_message: error.message
      )
    end
  end
end
