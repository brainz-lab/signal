module Mcp
  module Tools
    class SignalListAlerts < Base
      DESCRIPTION = "List active alerts and their status"
      SCHEMA = {
        type: "object",
        properties: {
          state: { type: "string", enum: ["firing", "pending", "resolved"], description: "Filter by state" },
          severity: { type: "string", enum: ["info", "warning", "critical"], description: "Filter by severity" },
          limit: { type: "integer", default: 20 }
        }
      }

      def call(args)
        alerts = Alert.for_project(@project_id)
          .includes(:alert_rule)
          .order(started_at: :desc)

        alerts = alerts.where(state: args[:state]) if args[:state]
        alerts = alerts.joins(:alert_rule).where(alert_rules: { severity: args[:severity] }) if args[:severity]
        alerts = alerts.limit(args[:limit] || 20)

        {
          alerts: alerts.map do |a|
            {
              id: a.id,
              rule: a.alert_rule.name,
              severity: a.alert_rule.severity,
              state: a.state,
              value: a.current_value,
              started: a.started_at.iso8601,
              duration: a.duration_human,
              acknowledged: a.acknowledged
            }
          end,
          summary: {
            firing: Alert.for_project(@project_id).firing.count,
            pending: Alert.for_project(@project_id).pending.count,
            critical: Alert.for_project(@project_id).joins(:alert_rule).where(alert_rules: { severity: 'critical' }).firing.count
          }
        }
      end
    end
  end
end
