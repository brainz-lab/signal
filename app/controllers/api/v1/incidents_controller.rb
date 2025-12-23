module Api
  module V1
    class IncidentsController < BaseController
      before_action :set_incident, only: [:show, :acknowledge, :resolve]

      def index
        incidents = Incident.for_project(@project_id).order(triggered_at: :desc)
        incidents = incidents.where(status: params[:status]) if params[:status].present?
        incidents = incidents.by_severity(params[:severity]) if params[:severity].present?
        incidents = incidents.limit(params[:limit] || 50)

        render json: {
          incidents: incidents.map { |i| serialize_incident(i) },
          total: incidents.count
        }
      end

      def show
        render json: serialize_incident(@incident, full: true)
      end

      def acknowledge
        @incident.acknowledge!(by: params[:by] || 'API')
        render json: serialize_incident(@incident)
      end

      def resolve
        @incident.resolve!(
          by: params[:by] || 'API',
          note: params[:note]
        )
        render json: serialize_incident(@incident)
      end

      private

      def set_incident
        @incident = Incident.for_project(@project_id).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def serialize_incident(incident, full: false)
        data = {
          id: incident.id,
          title: incident.title,
          summary: incident.summary,
          severity: incident.severity,
          status: incident.status,
          triggered_at: incident.triggered_at,
          acknowledged_at: incident.acknowledged_at,
          resolved_at: incident.resolved_at,
          duration: incident.duration.to_i,
          alerts_count: incident.alerts.count
        }

        if full
          data.merge!(
            acknowledged_by: incident.acknowledged_by,
            resolved_by: incident.resolved_by,
            resolution_note: incident.resolution_note,
            timeline: incident.timeline,
            affected_services: incident.affected_services,
            external_id: incident.external_id,
            external_url: incident.external_url,
            alerts: incident.alerts.map { |a| { id: a.id, state: a.state, rule: a.alert_rule.name } }
          )
        end

        data
      end
    end
  end
end
