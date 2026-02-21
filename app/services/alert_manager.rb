class AlertManager
  def initialize(rule)
    @rule = rule
    @project_id = rule.project_id
  end

  def process(result)
    fingerprint = result[:fingerprint]
    alert = find_or_initialize_alert(fingerprint)

    case result[:state]
    when "firing"
      handle_firing(alert, result)
    when "ok"
      handle_ok(alert, result)
    end
  end

  private

  def find_or_initialize_alert(fingerprint)
    @rule.alerts.find_or_initialize_by(fingerprint: fingerprint) do |a|
      a.project_id = @project_id
      a.state = "pending"
      a.started_at = Time.current
    end
  end

  def handle_firing(alert, result)
    alert.current_value = result[:value]
    alert.threshold_value = result[:threshold]
    alert.labels = result[:labels]

    case alert.state
    when "pending"
      if pending_long_enough?(alert)
        alert.fire!
      else
        alert.save!
        AlertsChannel.broadcast_alert(alert.project, alert)
      end
    when "firing"
      alert.update!(last_fired_at: Time.current)
    when "resolved", nil
      # New alert
      alert.state = "pending"
      alert.started_at = Time.current
      alert.resolved_at = nil
      alert.acknowledged = false
      alert.save!
      AlertsChannel.broadcast_alert(alert.project, alert)
    end
  end

  def handle_ok(alert, result)
    return unless alert.persisted?

    case alert.state
    when "firing"
      if ok_long_enough?(alert)
        alert.resolve!
      end
    when "pending"
      alert.destroy!
    end
  end

  def pending_long_enough?(alert)
    return true if @rule.pending_period.zero?
    alert.started_at < @rule.pending_period.seconds.ago
  end

  def ok_long_enough?(alert)
    # Check if the alert has been OK for the resolve period
    recent_history = AlertHistory
      .where(alert_rule: @rule, fingerprint: alert.fingerprint)
      .where("timestamp > ?", @rule.resolve_period.seconds.ago)
      .pluck(:state)

    recent_history.all? { |s| s == "ok" }
  end
end
