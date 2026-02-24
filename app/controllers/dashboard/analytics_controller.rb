module Dashboard
  class AnalyticsController < BaseController
    def show
      @range = params[:range] || "7d"
      @since = time_range_start(@range)

      alerts = @project.alerts.where("started_at >= ?", @since)
      resolved = alerts.where(state: "resolved").where.not(resolved_at: nil)
      acknowledged = alerts.where(acknowledged: true).where.not(acknowledged_at: nil)

      # Summary cards
      @total_alerts = alerts.count

      mtta_vals = acknowledged.pluck(:started_at, :acknowledged_at).map { |s, a| a - s }
      @mtta = mtta_vals.any? ? (mtta_vals.sum / mtta_vals.size).round : nil

      mttr_vals = resolved.pluck(:started_at, :resolved_at).map { |s, r| r - s }
      @mttr = mttr_vals.any? ? (mttr_vals.sum / mttr_vals.size).round : nil

      total_incidents = @project.incidents.where("triggered_at >= ?", @since).count
      resolved_incidents = @project.incidents.where(status: "resolved").where("triggered_at >= ?", @since).count
      @resolution_rate = total_incidents > 0 ? ((resolved_incidents.to_f / total_incidents) * 100).round(1) : 100.0

      # MTTA/MTTR trends by day
      @mtta_trend = compute_daily_metric(acknowledged, :started_at, :acknowledged_at)
      @mttr_trend = compute_daily_metric(resolved, :started_at, :resolved_at)

      # Alerts by source
      @alerts_by_source = alerts
        .joins(:alert_rule)
        .group("alert_rules.source")
        .count
        .sort_by { |_, v| -v }

      # Alerts by severity
      severity_counts = alerts.joins(:alert_rule).group("alert_rules.severity").count
      @severity_data = {
        critical: severity_counts["critical"] || 0,
        warning: severity_counts["warning"] || 0,
        info: severity_counts["info"] || 0
      }

      # Notification delivery stats
      notifications = @project.notifications.where("created_at >= ?", @since)
      @notification_stats = {
        sent: notifications.where(status: "sent").count,
        failed: notifications.where(status: "failed").count,
        skipped: notifications.where(status: "skipped").count
      }

      # Top noisy rules
      @noisy_rules = @project.alert_rules
        .joins(:alerts)
        .where(alerts: { started_at: @since.. })
        .group("alert_rules.id", "alert_rules.name", "alert_rules.severity", "alert_rules.source")
        .order("count_all DESC")
        .limit(10)
        .count
        .map { |(id, name, severity, source), count| { name: name, severity: severity, source: source, count: count } }

      # Channel performance
      @channel_stats = @project.notification_channels
        .left_joins(:notifications)
        .where(notifications: { created_at: @since.. })
        .or(@project.notification_channels.left_joins(:notifications).where(notifications: { id: nil }))
        .group("notification_channels.id", "notification_channels.name", "notification_channels.channel_type")
        .select(
          "notification_channels.id",
          "notification_channels.name",
          "notification_channels.channel_type",
          "COUNT(CASE WHEN notifications.status = 'sent' THEN 1 END) as sent_count",
          "COUNT(CASE WHEN notifications.status = 'failed' THEN 1 END) as failed_count"
        )
    end

    private

    def time_range_start(range)
      case range
      when "24h" then 24.hours.ago
      when "7d"  then 7.days.ago
      when "30d" then 30.days.ago
      else 7.days.ago
      end
    end

    def compute_daily_metric(relation, start_col, end_col)
      relation
        .group("date_trunc('day', #{start_col})")
        .order(Arel.sql("date_trunc('day', #{start_col})"))
        .pluck(Arel.sql("date_trunc('day', #{start_col})"), Arel.sql("AVG(EXTRACT(EPOCH FROM (#{end_col} - #{start_col})))"))
        .map { |day, avg| { x: day.iso8601, y: avg&.round || 0 } }
    end
  end
end
