module Dashboard
  class ExportsController < BaseController
    def create
      alerts = @project.alerts.includes(:alert_rule).order(started_at: :desc)

      # Apply filters
      alerts = alerts.where(state: params[:state]) if params[:state].present?
      alerts = alerts.where("started_at >= ?", params[:since]) if params[:since].present?
      alerts = alerts.where("started_at <= ?", params[:until]) if params[:until].present?

      if params[:severity].present?
        alerts = alerts.joins(:alert_rule).where(alert_rules: { severity: params[:severity] })
      end

      format = params[:format_type] || "json"
      exported = AlertExporter.new(alerts).send("to_#{format}")

      case format
      when "csv"
        send_data exported,
          filename: "signal-alerts-#{Date.current}.csv",
          type: "text/csv",
          disposition: "attachment"
      else
        send_data exported,
          filename: "signal-alerts-#{Date.current}.json",
          type: "application/json",
          disposition: "attachment"
      end
    end
  end
end
