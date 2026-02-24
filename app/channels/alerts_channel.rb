class AlertsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "alerts_#{params[:project_id]}"
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_alert(project, alert)
    ActionCable.server.broadcast("alerts_#{project.id}", {
      type: "alert_update",
      alert: {
        id: alert.id,
        state: alert.state,
        severity: alert.alert_rule&.severity,
        rule_name: alert.alert_rule&.name,
        current_value: alert.current_value,
        threshold_value: alert.threshold_value,
        started_at: alert.started_at&.iso8601,
        resolved_at: alert.resolved_at&.iso8601,
        acknowledged: alert.acknowledged,
        fingerprint: alert.fingerprint
      }
    })
  end

  def self.broadcast_incident(project, incident)
    ActionCable.server.broadcast("alerts_#{project.id}", {
      type: "incident_update",
      incident: {
        id: incident.id,
        status: incident.status,
        severity: incident.severity,
        title: incident.title,
        triggered_at: incident.triggered_at&.iso8601,
        resolved_at: incident.resolved_at&.iso8601
      }
    })
  end
end
