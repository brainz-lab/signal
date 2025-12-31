module Dashboard
  class AlertsController < BaseController
    def index
      @alerts = @project.alerts.includes(:alert_rule).order(started_at: :desc)

      # Filter by state
      if params[:state].present?
        @alerts = @alerts.where(state: params[:state])
      end

      # Filter by severity
      if params[:severity].present?
        @alerts = @alerts.joins(:alert_rule).where(alert_rules: { severity: params[:severity] })
      end

      # Filter by acknowledged
      if params[:unacknowledged] == "true"
        @alerts = @alerts.where(acknowledged: false)
      end

      @alerts = @alerts.limit(100)

      # Stats
      @firing_count = @project.alerts.where(state: "firing").count
      @pending_count = @project.alerts.where(state: "pending").count
      @resolved_today = @project.alerts.where(state: "resolved").where("resolved_at > ?", Time.current.beginning_of_day).count
    end

    def show
      @alert = @project.alerts.includes(:alert_rule, :incident).find(params[:id])
    end

    def acknowledge
      @alert = @project.alerts.find(params[:id])
      @alert.acknowledge!(by: "Dashboard User")
      redirect_to dashboard_project_alert_path(@project, @alert), notice: "Alert acknowledged"
    end
  end
end
