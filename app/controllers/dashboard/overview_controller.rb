module Dashboard
  class OverviewController < BaseController
    def show
      @range = params[:range] || "24h"
      @since = time_range_start(@range)

      alerts = @project.alerts.where("started_at >= ?", @since)
      resolved_alerts = @project.alerts.where(state: "resolved").where("resolved_at >= ?", @since)
      acked_alerts = @project.alerts.where(acknowledged: true).where("acknowledged_at >= ?", @since)

      # KPI cards
      @firing_count = @project.alerts.where(state: "firing").count
      @pending_count = @project.alerts.where(state: "pending").count
      @incidents_open = @project.incidents.where(status: %w[triggered acknowledged]).count
      @resolved_today = resolved_alerts.count

      # MTTA: avg time from started_at → acknowledged_at
      mtta_seconds = acked_alerts
        .where.not(acknowledged_at: nil)
        .pluck(:started_at, :acknowledged_at)
        .map { |s, a| a - s }
      @mtta = mtta_seconds.any? ? (mtta_seconds.sum / mtta_seconds.size).round : nil

      # MTTR: avg time from started_at → resolved_at
      mttr_seconds = resolved_alerts
        .where.not(resolved_at: nil)
        .pluck(:started_at, :resolved_at)
        .map { |s, r| r - s }
      @mttr = mttr_seconds.any? ? (mttr_seconds.sum / mttr_seconds.size).round : nil

      # Alert volume over time (grouped by hour)
      truncation = @range.in?(%w[7d 30d]) ? "day" : "hour"
      @alert_volume_data = alerts
        .group("date_trunc('#{truncation}', started_at)")
        .order(Arel.sql("date_trunc('#{truncation}', started_at)"))
        .count
        .map { |time, count| { x: time.iso8601, y: count } }

      # Severity distribution
      severity_counts = alerts.joins(:alert_rule).group("alert_rules.severity").count
      @severity_data = {
        critical: severity_counts["critical"] || 0,
        warning: severity_counts["warning"] || 0,
        info: severity_counts["info"] || 0
      }

      # Top firing rules
      @top_rules = @project.alert_rules
        .joins(:alerts)
        .where(alerts: { state: "firing" })
        .group("alert_rules.id")
        .order("count_all DESC")
        .limit(5)
        .count
        .map { |rule_id, count| [AlertRule.find(rule_id), count] }

      # Recent alerts
      @recent_alerts = @project.alerts.includes(:alert_rule).order(started_at: :desc).limit(10)

      # Notification success rate
      notifications = @project.notifications.where("created_at >= ?", @since)
      total_sent = notifications.where(status: %w[sent failed]).count
      sent_ok = notifications.where(status: "sent").count
      @notification_rate = total_sent > 0 ? ((sent_ok.to_f / total_sent) * 100).round(1) : 100.0
    end

    private

    def time_range_start(range)
      case range
      when "1h"  then 1.hour.ago
      when "6h"  then 6.hours.ago
      when "24h" then 24.hours.ago
      when "7d"  then 7.days.ago
      when "30d" then 30.days.ago
      else 24.hours.ago
      end
    end
  end
end
