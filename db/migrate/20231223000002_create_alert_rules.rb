class CreateAlertRules < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_rules, id: :uuid do |t|
      t.uuid :project_id, null: false

      t.string :name, null: false
      t.text :description
      t.string :slug, null: false

      # Data source configuration
      t.string :source, null: false           # flux, pulse, reflex, recall
      t.string :source_type                   # metric, event, error, log
      t.string :source_name                   # metric name, event name, etc.

      # Rule type
      t.string :rule_type, null: false        # threshold, anomaly, absence, composite

      # Condition (for threshold rules)
      t.string :operator                      # gt, gte, lt, lte, eq, neq
      t.float :threshold
      t.string :aggregation                   # avg, sum, count, min, max, p95, p99
      t.string :window                        # 1m, 5m, 15m, 1h, 24h

      # Query/filter
      t.jsonb :query, default: {}             # Additional filters
      t.jsonb :group_by, default: []          # Group alerts by dimensions

      # For anomaly detection
      t.float :sensitivity                    # 1-10, higher = more sensitive
      t.string :baseline_window               # 1h, 24h, 7d

      # For absence detection
      t.string :expected_interval             # How often data should arrive

      # For composite rules
      t.jsonb :composite_rules, default: []   # Array of sub-rule configs
      t.string :composite_operator            # and, or

      # Severity & notifications
      t.string :severity, default: 'warning'  # info, warning, critical
      t.jsonb :notify_channels, default: []   # Channel IDs to notify
      t.uuid :escalation_policy_id

      # Timing
      t.integer :evaluation_interval, default: 60  # seconds
      t.integer :pending_period, default: 0        # seconds before firing
      t.integer :resolve_period, default: 300      # seconds of OK before resolved

      # State
      t.boolean :enabled, default: true
      t.boolean :muted, default: false
      t.datetime :muted_until
      t.string :muted_reason

      t.jsonb :labels, default: {}            # Custom labels
      t.jsonb :annotations, default: {}       # runbook_url, dashboard_url, etc.

      t.datetime :last_evaluated_at
      t.string :last_state                    # ok, pending, firing

      t.timestamps

      t.index [:project_id, :slug], unique: true
      t.index [:project_id, :source, :enabled]
      t.index [:project_id, :severity]
      t.index :project_id
    end
  end
end
