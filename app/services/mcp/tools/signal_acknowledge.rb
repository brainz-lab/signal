module Mcp
  module Tools
    class SignalAcknowledge < Base
      DESCRIPTION = "Acknowledge an alert"
      SCHEMA = {
        type: "object",
        properties: {
          alert_id: { type: "string", description: "Alert ID to acknowledge" },
          note: { type: "string", description: "Optional acknowledgment note" }
        },
        required: ["alert_id"]
      }

      def call(args)
        alert = Alert.for_project(@project_id).find(args[:alert_id])
        alert.acknowledge!(by: "MCP", note: args[:note])

        {
          success: true,
          alert: {
            id: alert.id,
            rule: alert.alert_rule.name,
            acknowledged: true,
            acknowledged_at: alert.acknowledged_at.iso8601
          }
        }
      end
    end
  end
end
