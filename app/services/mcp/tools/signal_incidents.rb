module Mcp
  module Tools
    class SignalIncidents < Base
      DESCRIPTION = "List incidents"
      SCHEMA = {
        type: "object",
        properties: {
          status: { type: "string", enum: [ "triggered", "acknowledged", "resolved" ] },
          limit: { type: "integer", default: 10 }
        }
      }

      def call(args)
        incidents = Incident.for_project(@project_id).order(triggered_at: :desc)
        incidents = incidents.where(status: args[:status]) if args[:status]
        incidents = incidents.limit(args[:limit] || 10)

        {
          incidents: incidents.map do |i|
            {
              id: i.id,
              title: i.title,
              severity: i.severity,
              status: i.status,
              triggered_at: i.triggered_at.iso8601,
              duration: (i.resolved_at || Time.current) - i.triggered_at,
              alerts_count: i.alerts.count
            }
          end
        }
      end
    end
  end
end
