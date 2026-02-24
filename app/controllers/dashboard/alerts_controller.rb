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

      # Text search on rule name or alert labels
      if params[:q].present?
        search_term = "%#{params[:q]}%"
        @alerts = @alerts.joins(:alert_rule)
          .where("alert_rules.name ILIKE :q OR alerts.labels::text ILIKE :q", q: search_term)
      end

      # Date range filter
      if params[:since].present?
        @alerts = @alerts.where("alerts.started_at >= ?", params[:since])
      end
      if params[:until].present?
        @alerts = @alerts.where("alerts.started_at <= ?", params[:until])
      end

      # Source filter
      if params[:source].present?
        @alerts = @alerts.joins(:alert_rule).where(alert_rules: { source: params[:source] })
      end

      # Rule filter
      if params[:rule_id].present?
        @alerts = @alerts.where(alert_rule_id: params[:rule_id])
      end

      # Sort options
      case params[:sort]
      when "oldest"
        @alerts = @alerts.reorder(started_at: :asc)
      when "severity"
        @alerts = @alerts.joins(:alert_rule).reorder(Arel.sql("CASE alert_rules.severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END, alerts.started_at DESC"))
      when "duration"
        @alerts = @alerts.reorder(Arel.sql("COALESCE(resolved_at, NOW()) - started_at DESC"))
      end

      @alerts = @alerts.limit(100)

      # Stats
      @firing_count = @project.alerts.where(state: "firing").count
      @pending_count = @project.alerts.where(state: "pending").count
      @resolved_today = @project.alerts.where(state: "resolved").where("resolved_at > ?", Time.current.beginning_of_day).count

      # Saved searches
      @saved_searches = @project.saved_searches.recent.limit(10)
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
