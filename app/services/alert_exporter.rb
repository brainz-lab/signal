class AlertExporter
  def initialize(alerts)
    @alerts = alerts
  end

  def to_json
    @alerts.map { |a| serialize(a) }.to_json
  end

  def to_csv
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << csv_headers
      @alerts.find_each do |alert|
        csv << csv_row(alert)
      end
    end
  end

  private

  def serialize(alert)
    {
      id: alert.id,
      rule_name: alert.alert_rule&.name,
      severity: alert.alert_rule&.severity,
      state: alert.state,
      current_value: alert.current_value,
      threshold_value: alert.threshold_value,
      started_at: alert.started_at&.iso8601,
      resolved_at: alert.resolved_at&.iso8601,
      duration_seconds: alert.duration.round,
      labels: alert.labels,
      acknowledged: alert.acknowledged,
      acknowledged_by: alert.acknowledged_by
    }
  end

  def csv_headers
    %w[id rule_name severity state current_value threshold_value started_at resolved_at duration_seconds labels acknowledged acknowledged_by]
  end

  def csv_row(alert)
    [
      alert.id,
      alert.alert_rule&.name,
      alert.alert_rule&.severity,
      alert.state,
      alert.current_value,
      alert.threshold_value,
      alert.started_at&.iso8601,
      alert.resolved_at&.iso8601,
      alert.duration.round,
      alert.labels&.to_json,
      alert.acknowledged,
      alert.acknowledged_by
    ]
  end
end
