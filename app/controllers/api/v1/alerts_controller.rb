module Api
  module V1
    class AlertsController < BaseController
      def index
        alerts = Alert.for_project(@project_id)
          .includes(:alert_rule, :incident)
          .order(started_at: :desc)

        alerts = alerts.where(state: params[:state]) if params[:state].present?
        alerts = alerts.joins(:alert_rule).where(alert_rules: { severity: params[:severity] }) if params[:severity].present?
        alerts = alerts.unacknowledged if params[:unacknowledged] == "true"

        alerts = alerts.limit(params[:limit] || 50)

        render json: {
          alerts: alerts.map { |a| serialize_alert(a) },
          total: alerts.count
        }
      end

      def show
        alert = Alert.for_project(@project_id).find(params[:id])
        render json: serialize_alert(alert, full: true)
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def acknowledge
        alert = Alert.for_project(@project_id).find(params[:id])
        alert.acknowledge!(
          by: params[:by] || "API",
          note: params[:note]
        )

        render json: serialize_alert(alert)
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def trigger
        # Manual alert trigger
        rule = AlertRule.for_project(@project_id).find_by!(name: params[:name])

        alert = rule.alerts.create!(
          project_id: @project_id,
          fingerprint: Digest::SHA256.hexdigest("manual:#{rule.id}:#{Time.current}"),
          state: "firing",
          started_at: Time.current,
          last_fired_at: Time.current,
          current_value: params[:value],
          labels: params[:labels] || {}
        )

        render json: serialize_alert(alert), status: :created
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def resolve_by_name
        rule = AlertRule.for_project(@project_id).find_by!(name: params[:name])
        alerts = rule.alerts.firing

        alerts.each(&:resolve!)

        render json: { resolved_count: alerts.count }
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      private

      def serialize_alert(alert, full: false)
        data = {
          id: alert.id,
          rule: {
            id: alert.alert_rule.id,
            name: alert.alert_rule.name,
            severity: alert.alert_rule.severity
          },
          state: alert.state,
          fingerprint: alert.fingerprint,
          labels: alert.labels,
          current_value: alert.current_value,
          threshold_value: alert.threshold_value,
          started_at: alert.started_at,
          resolved_at: alert.resolved_at,
          duration: alert.duration.to_i,
          acknowledged: alert.acknowledged,
          acknowledged_by: alert.acknowledged_by
        }

        if full
          data[:incident] = alert.incident&.as_json(only: [ :id, :title, :status ])
          data[:notifications] = alert.notifications.order(created_at: :desc).limit(10).as_json
          data[:rule_full] = alert.alert_rule.as_json(except: [ :project_id ])
        end

        data
      end
    end
  end
end
