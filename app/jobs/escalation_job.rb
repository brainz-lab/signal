class EscalationJob < ApplicationJob
  queue_as :alerts

  def perform(alert_id:, step_index:)
    alert = Alert.find(alert_id)
    return if alert.state != "firing" || alert.acknowledged

    policy = alert.alert_rule.escalation_policy
    return unless policy

    step = policy.steps[step_index]
    return unless step

    # Send notifications for this step
    step["channels"].each do |channel_id|
      NotificationJob.perform_later(
        channel_id: channel_id,
        alert_id: alert.id,
        notification_type: "escalation"
      )
    end

    # Schedule next step if exists
    next_step = policy.steps[step_index + 1]
    if next_step
      EscalationJob.set(wait: next_step["delay_minutes"].minutes).perform_later(
        alert_id: alert.id,
        step_index: step_index + 1
      )
    elsif policy.repeat && policy.repeat_after_minutes.present?
      # Repeat from beginning
      EscalationJob.set(wait: policy.repeat_after_minutes.minutes).perform_later(
        alert_id: alert.id,
        step_index: 0
      )
    end
  end
end
