module Mcp
  module Tools
    class SignalMute < Base
      DESCRIPTION = "Mute an alert rule"
      SCHEMA = {
        type: "object",
        properties: {
          rule_id: { type: "string", description: "Rule ID to mute" },
          duration: { type: "string", description: "Mute duration (1h, 4h, 24h, 7d)", default: "1h" },
          reason: { type: "string", description: "Reason for muting" }
        },
        required: [ "rule_id" ]
      }

      def call(args)
        rule = AlertRule.for_project(@project_id).find(args[:rule_id])

        until_time = parse_duration(args[:duration] || "1h")
        rule.mute!(until_time: until_time, reason: args[:reason])

        {
          success: true,
          rule: rule.name,
          muted_until: until_time.iso8601,
          reason: args[:reason]
        }
      end

      private

      def parse_duration(duration)
        match = duration.match(/^(\d+)(h|d)$/)
        return 1.hour.from_now unless match

        value = match[1].to_i
        case match[2]
        when "h" then value.hours.from_now
        when "d" then value.days.from_now
        end
      end
    end
  end
end
