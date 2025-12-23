module Mcp
  module Tools
    class SignalCreateRule < Base
      DESCRIPTION = "Create a new alert rule"
      SCHEMA = {
        type: "object",
        properties: {
          name: { type: "string", description: "Rule name" },
          source: { type: "string", enum: ["flux", "pulse", "reflex", "recall"] },
          source_name: { type: "string", description: "Metric or event name to monitor" },
          operator: { type: "string", enum: ["gt", "gte", "lt", "lte", "eq", "neq"] },
          threshold: { type: "number" },
          window: { type: "string", default: "5m", description: "Time window (1m, 5m, 15m, 1h)" },
          severity: { type: "string", enum: ["info", "warning", "critical"], default: "warning" }
        },
        required: ["name", "source", "source_name", "operator", "threshold"]
      }

      def call(args)
        rule = AlertRule.create!(
          project_id: @project_id,
          name: args[:name],
          source: args[:source],
          source_name: args[:source_name],
          rule_type: 'threshold',
          operator: args[:operator],
          threshold: args[:threshold],
          aggregation: 'avg',
          window: args[:window] || '5m',
          severity: args[:severity] || 'warning',
          enabled: true
        )

        {
          success: true,
          rule: {
            id: rule.id,
            name: rule.name,
            condition: rule.condition_description,
            severity: rule.severity
          }
        }
      end
    end
  end
end
