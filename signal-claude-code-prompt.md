# Signal - Alerting & Notifications

## The Vision

**Signal** is the unified alerting system for Brainz Lab. It monitors all your data sources, detects issues, and notifies your team through Slack, PagerDuty, email, and webhooks.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                               SIGNAL                                         │
│                     "Know before your users do"                              │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   DATA SOURCES                           ALERT RULES                 │   │
│   │   ────────────                           ───────────                 │   │
│   │   Flux (metrics/events)  ─────┐          ┌─── Threshold (> < = !=)   │   │
│   │   Pulse (APM traces)     ─────┼────────▶ │─── Anomaly (AI-detected)  │   │
│   │   Reflex (errors)        ─────┤          │─── Absence (no data)      │   │
│   │   Recall (logs)          ─────┘          └─── Composite (A AND B)    │   │
│   │                                                                      │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   NOTIFICATION CHANNELS                                              │   │
│   │   ─────────────────────                                              │   │
│   │                                                                      │   │
│   │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │   │
│   │   │  Slack   │  │PagerDuty │  │  Email   │  │ Webhook  │            │   │
│   │   │   #ops   │  │ On-call  │  │  team@   │  │ https:// │            │   │
│   │   └──────────┘  └──────────┘  └──────────┘  └──────────┘            │   │
│   │                                                                      │   │
│   │   ┌──────────┐  ┌──────────┐  ┌──────────┐                          │   │
│   │   │ Discord  │  │  Teams   │  │ Opsgenie │                          │   │
│   │   │  #alerts │  │ channel  │  │ On-call  │                          │   │
│   │   └──────────┘  └──────────┘  └──────────┘                          │   │
│   │                                                                      │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   ALERT TIMELINE                                                     │   │
│   │   ──────────────                                                     │   │
│   │                                                                      │   │
│   │   🔴 CRITICAL   Error rate > 5%               2 min ago   FIRING     │   │
│   │   🟡 WARNING    Response time p95 > 500ms     15 min ago  FIRING     │   │
│   │   🟢 RESOLVED   Memory usage > 90%            1 hour ago  OK         │   │
│   │   🔴 CRITICAL   No heartbeat from worker      3 hours ago FIRING     │   │
│   │                                                                      │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Features: Escalations │ On-call schedules │ Maintenance windows           │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
services/signal/
├── README.md
├── LICENSE
├── Dockerfile
├── docker-compose.yml
│
├── config/
│   ├── routes.rb
│   ├── initializers/
│   │   ├── sidekiq.rb
│   │   └── redis.rb
│   └── locales/
│
├── app/
│   ├── controllers/
│   │   ├── api/v1/
│   │   │   ├── base_controller.rb
│   │   │   ├── alerts_controller.rb
│   │   │   ├── rules_controller.rb
│   │   │   ├── channels_controller.rb
│   │   │   ├── incidents_controller.rb
│   │   │   └── webhooks_controller.rb
│   │   ├── dashboard/
│   │   │   ├── base_controller.rb
│   │   │   ├── alerts_controller.rb
│   │   │   ├── rules_controller.rb
│   │   │   └── channels_controller.rb
│   │   └── mcp/
│   │       └── tools_controller.rb
│   │
│   ├── models/
│   │   ├── alert_rule.rb
│   │   ├── alert.rb
│   │   ├── incident.rb
│   │   ├── notification_channel.rb
│   │   ├── notification.rb
│   │   ├── escalation_policy.rb
│   │   ├── on_call_schedule.rb
│   │   ├── maintenance_window.rb
│   │   └── alert_history.rb
│   │
│   ├── services/
│   │   ├── rule_evaluator.rb
│   │   ├── alert_manager.rb
│   │   ├── incident_manager.rb
│   │   ├── notifiers/
│   │   │   ├── base.rb
│   │   │   ├── slack.rb
│   │   │   ├── pagerduty.rb
│   │   │   ├── email.rb
│   │   │   ├── webhook.rb
│   │   │   ├── discord.rb
│   │   │   ├── teams.rb
│   │   │   └── opsgenie.rb
│   │   ├── data_sources/
│   │   │   ├── base.rb
│   │   │   ├── flux.rb
│   │   │   ├── pulse.rb
│   │   │   ├── reflex.rb
│   │   │   └── recall.rb
│   │   └── mcp/
│   │       ├── server.rb
│   │       └── tools/
│   │           ├── signal_list_alerts.rb
│   │           ├── signal_acknowledge.rb
│   │           ├── signal_create_rule.rb
│   │           ├── signal_mute.rb
│   │           └── signal_incidents.rb
│   │
│   ├── jobs/
│   │   ├── rule_evaluation_job.rb
│   │   ├── notification_job.rb
│   │   ├── escalation_job.rb
│   │   └── digest_job.rb
│   │
│   ├── channels/
│   │   └── alerts_channel.rb
│   │
│   └── views/
│       ├── layouts/
│       └── dashboard/
│
└── db/
    └── migrate/
```

---

## Database Schema

```ruby
# db/migrate/001_create_alert_rules.rb

class CreateAlertRules < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :alert_rules, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
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
      t.references :escalation_policy, type: :uuid
      
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
    end
  end
end

# db/migrate/002_create_alerts.rb

class CreateAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :alerts, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      t.references :alert_rule, type: :uuid, null: false, foreign_key: true
      
      # Identification (for grouping)
      t.string :fingerprint, null: false      # Hash of rule + labels
      t.jsonb :labels, default: {}            # Dimension values that triggered
      
      # State
      t.string :state, null: false            # pending, firing, resolved
      t.datetime :started_at, null: false
      t.datetime :resolved_at
      t.datetime :last_fired_at
      
      # Value that triggered
      t.float :current_value
      t.float :threshold_value
      
      # Notification tracking
      t.datetime :last_notified_at
      t.integer :notification_count, default: 0
      
      # Acknowledgment
      t.boolean :acknowledged, default: false
      t.datetime :acknowledged_at
      t.string :acknowledged_by
      t.text :acknowledgment_note
      
      # Incident link
      t.references :incident, type: :uuid
      
      t.timestamps
      
      t.index [:project_id, :state]
      t.index [:alert_rule_id, :fingerprint], unique: true, where: "state != 'resolved'"
      t.index [:project_id, :started_at]
      t.index :fingerprint
    end
  end
end

# db/migrate/003_create_incidents.rb

class CreateIncidents < ActiveRecord::Migration[8.0]
  def change
    create_table :incidents, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :title, null: false
      t.text :summary
      t.string :severity, null: false         # info, warning, critical
      t.string :status, null: false           # triggered, acknowledged, resolved
      
      t.datetime :triggered_at, null: false
      t.datetime :acknowledged_at
      t.datetime :resolved_at
      
      t.string :acknowledged_by
      t.string :resolved_by
      t.text :resolution_note
      
      # Timeline of events
      t.jsonb :timeline, default: []
      # [
      #   { at: "2025-01-01T12:00:00Z", type: "triggered", message: "Error rate exceeded 5%" },
      #   { at: "2025-01-01T12:02:00Z", type: "notification", channel: "slack", status: "sent" },
      #   { at: "2025-01-01T12:05:00Z", type: "acknowledged", by: "alice@example.com" }
      # ]
      
      # Affected services/components
      t.jsonb :affected_services, default: []
      
      # External links
      t.string :external_id                   # PagerDuty incident ID, etc.
      t.string :external_url
      
      t.timestamps
      
      t.index [:project_id, :status]
      t.index [:project_id, :triggered_at]
      t.index [:project_id, :severity]
    end
  end
end

# db/migrate/004_create_notification_channels.rb

class CreateNotificationChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_channels, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :name, null: false
      t.string :slug, null: false
      t.string :channel_type, null: false     # slack, pagerduty, email, webhook, discord, teams, opsgenie
      
      # Configuration (encrypted)
      t.jsonb :config, default: {}
      # Slack: { webhook_url: "...", channel: "#ops" }
      # PagerDuty: { routing_key: "...", severity_map: { critical: "critical", warning: "warning" } }
      # Email: { to: ["team@example.com"], subject_prefix: "[Alert]" }
      # Webhook: { url: "...", method: "POST", headers: {}, template: "..." }
      
      # Testing & status
      t.boolean :verified, default: false
      t.datetime :last_tested_at
      t.string :last_test_status
      t.datetime :last_used_at
      t.integer :success_count, default: 0
      t.integer :failure_count, default: 0
      
      t.boolean :enabled, default: true
      
      t.timestamps
      
      t.index [:project_id, :slug], unique: true
      t.index [:project_id, :channel_type]
    end
  end
end

# db/migrate/005_create_notifications.rb

class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      t.references :alert, type: :uuid, foreign_key: true
      t.references :incident, type: :uuid, foreign_key: true
      t.references :notification_channel, type: :uuid, null: false, foreign_key: true
      
      t.string :notification_type, null: false  # alert_fired, alert_resolved, incident_triggered, etc.
      t.string :status, null: false             # pending, sent, failed, skipped
      
      t.jsonb :payload, default: {}             # What was sent
      t.jsonb :response, default: {}            # Response from channel
      
      t.text :error_message
      t.integer :retry_count, default: 0
      t.datetime :sent_at
      t.datetime :next_retry_at
      
      t.timestamps
      
      t.index [:project_id, :created_at]
      t.index [:notification_channel_id, :status]
      t.index [:status, :next_retry_at], where: "status = 'failed'"
    end
  end
end

# db/migrate/006_create_escalation_policies.rb

class CreateEscalationPolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :escalation_policies, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      
      # Escalation steps
      t.jsonb :steps, default: []
      # [
      #   { delay_minutes: 0, channels: ["uuid1", "uuid2"], notify: "all" },
      #   { delay_minutes: 15, channels: ["uuid3"], notify: "on_call" },
      #   { delay_minutes: 30, channels: ["uuid4"], notify: "all" }
      # ]
      
      # Repeat behavior
      t.boolean :repeat, default: false
      t.integer :repeat_after_minutes
      t.integer :max_repeats
      
      t.boolean :enabled, default: true
      
      t.timestamps
      
      t.index [:project_id, :slug], unique: true
    end
  end
end

# db/migrate/007_create_on_call_schedules.rb

class CreateOnCallSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :on_call_schedules, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :name, null: false
      t.string :slug, null: false
      t.string :timezone, default: 'UTC'
      
      # Schedule type
      t.string :schedule_type, null: false    # weekly, custom
      
      # For weekly rotation
      t.jsonb :weekly_schedule, default: {}
      # {
      #   monday: { start: "09:00", end: "17:00", user: "alice@example.com" },
      #   tuesday: { start: "09:00", end: "17:00", user: "bob@example.com" },
      #   ...
      # }
      
      # Rotation members
      t.jsonb :members, default: []           # List of user emails
      t.string :rotation_type                 # daily, weekly
      t.datetime :rotation_start              # When rotation started
      
      # Current on-call
      t.string :current_on_call
      t.datetime :current_shift_start
      t.datetime :current_shift_end
      
      t.boolean :enabled, default: true
      
      t.timestamps
      
      t.index [:project_id, :slug], unique: true
    end
  end
end

# db/migrate/008_create_maintenance_windows.rb

class CreateMaintenanceWindows < ActiveRecord::Migration[8.0]
  def change
    create_table :maintenance_windows, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :name, null: false
      t.text :description
      
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      
      # Scope: which rules to mute
      t.jsonb :rule_ids, default: []          # Empty = all rules
      t.jsonb :services, default: []          # Filter by service label
      
      # Recurrence
      t.boolean :recurring, default: false
      t.string :recurrence_rule              # RRULE format
      
      t.string :created_by
      t.boolean :active, default: true
      
      t.timestamps
      
      t.index [:project_id, :starts_at, :ends_at]
      t.index [:project_id, :active]
    end
  end
end

# db/migrate/009_create_alert_history.rb

class CreateAlertHistory < ActiveRecord::Migration[8.0]
  def change
    create_table :alert_history, id: :uuid do |t|
      t.references :project, type: :uuid, null: false
      t.references :alert_rule, type: :uuid, null: false
      
      t.datetime :timestamp, null: false
      t.string :state, null: false            # ok, pending, firing
      t.float :value
      t.jsonb :labels, default: {}
      
      t.string :fingerprint
      
      t.index [:project_id, :timestamp]
      t.index [:alert_rule_id, :timestamp]
    end

    # Convert to hypertable for TimescaleDB
    execute "SELECT create_hypertable('alert_history', 'timestamp');"
    
    # Compression after 7 days
    execute <<-SQL
      ALTER TABLE alert_history SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'project_id, alert_rule_id'
      );
      SELECT add_compression_policy('alert_history', INTERVAL '7 days');
    SQL
    
    # Retention: 90 days
    execute "SELECT add_retention_policy('alert_history', INTERVAL '90 days');"
  end
end
```

---

## Models

```ruby
# app/models/alert_rule.rb

class AlertRule < ApplicationRecord
  belongs_to :project
  belongs_to :escalation_policy, optional: true
  has_many :alerts, dependent: :destroy
  has_many :alert_history, dependent: :destroy
  
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :project_id }
  validates :source, presence: true, inclusion: { in: %w[flux pulse reflex recall] }
  validates :rule_type, presence: true, inclusion: { in: %w[threshold anomaly absence composite] }
  validates :severity, inclusion: { in: %w[info warning critical] }
  
  before_validation :generate_slug, on: :create
  
  scope :enabled, -> { where(enabled: true) }
  scope :active, -> { enabled.where(muted: false).where('muted_until IS NULL OR muted_until < ?', Time.current) }
  scope :by_source, ->(source) { where(source: source) }
  scope :firing, -> { joins(:alerts).where(alerts: { state: 'firing' }).distinct }
  
  OPERATORS = {
    'gt' => '>',
    'gte' => '>=',
    'lt' => '<',
    'lte' => '<=',
    'eq' => '==',
    'neq' => '!='
  }.freeze
  
  def evaluate!
    evaluator = RuleEvaluator.new(self)
    result = evaluator.evaluate
    
    update!(
      last_evaluated_at: Time.current,
      last_state: result[:state]
    )
    
    # Record history
    AlertHistory.create!(
      project: project,
      alert_rule: self,
      timestamp: Time.current,
      state: result[:state],
      value: result[:value],
      labels: result[:labels] || {},
      fingerprint: result[:fingerprint]
    )
    
    # Handle state transitions
    AlertManager.new(self).process(result)
    
    result
  end
  
  def mute!(until_time: nil, reason: nil)
    update!(
      muted: true,
      muted_until: until_time,
      muted_reason: reason
    )
  end
  
  def unmute!
    update!(muted: false, muted_until: nil, muted_reason: nil)
  end
  
  def muted?
    return false unless muted
    return true if muted_until.nil?
    muted_until > Time.current
  end
  
  def notification_channels
    NotificationChannel.where(id: notify_channels)
  end
  
  def condition_description
    case rule_type
    when 'threshold'
      "#{aggregation}(#{source_name}) #{OPERATORS[operator]} #{threshold} over #{window}"
    when 'anomaly'
      "Anomaly detected in #{source_name} (sensitivity: #{sensitivity})"
    when 'absence'
      "No data for #{source_name} in #{expected_interval}"
    when 'composite'
      "Composite rule: #{composite_rules.count} sub-rules"
    end
  end
  
  private
  
  def generate_slug
    self.slug ||= name&.parameterize
  end
end

# app/models/alert.rb

class Alert < ApplicationRecord
  belongs_to :project
  belongs_to :alert_rule
  belongs_to :incident, optional: true
  has_many :notifications, dependent: :destroy
  
  validates :fingerprint, presence: true
  validates :state, presence: true, inclusion: { in: %w[pending firing resolved] }
  
  scope :active, -> { where(state: %w[pending firing]) }
  scope :firing, -> { where(state: 'firing') }
  scope :pending, -> { where(state: 'pending') }
  scope :resolved, -> { where(state: 'resolved') }
  scope :unacknowledged, -> { where(acknowledged: false) }
  scope :recent, -> { order(started_at: :desc) }
  
  def fire!
    update!(
      state: 'firing',
      last_fired_at: Time.current
    )
    
    # Create or update incident
    IncidentManager.new(self).fire!
    
    # Send notifications
    notify!(:alert_fired)
  end
  
  def resolve!
    update!(
      state: 'resolved',
      resolved_at: Time.current
    )
    
    # Update incident
    IncidentManager.new(self).resolve!
    
    # Send resolution notification
    notify!(:alert_resolved)
  end
  
  def acknowledge!(by:, note: nil)
    update!(
      acknowledged: true,
      acknowledged_at: Time.current,
      acknowledged_by: by,
      acknowledgment_note: note
    )
    
    # Update incident
    incident&.acknowledge!(by: by)
  end
  
  def duration
    end_time = resolved_at || Time.current
    end_time - started_at
  end
  
  def duration_human
    ActiveSupport::Duration.build(duration.to_i).inspect
  end
  
  def severity
    alert_rule.severity
  end
  
  private
  
  def notify!(notification_type)
    return if alert_rule.muted?
    
    alert_rule.notification_channels.each do |channel|
      NotificationJob.perform_later(
        channel_id: channel.id,
        alert_id: id,
        notification_type: notification_type.to_s
      )
    end
    
    update!(
      last_notified_at: Time.current,
      notification_count: notification_count + 1
    )
  end
end

# app/models/notification_channel.rb

class NotificationChannel < ApplicationRecord
  belongs_to :project
  has_many :notifications, dependent: :destroy
  
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :project_id }
  validates :channel_type, presence: true, inclusion: { 
    in: %w[slack pagerduty email webhook discord teams opsgenie]
  }
  
  before_validation :generate_slug, on: :create
  encrypts :config
  
  scope :enabled, -> { where(enabled: true) }
  
  def notifier
    case channel_type
    when 'slack' then Notifiers::Slack.new(self)
    when 'pagerduty' then Notifiers::Pagerduty.new(self)
    when 'email' then Notifiers::Email.new(self)
    when 'webhook' then Notifiers::Webhook.new(self)
    when 'discord' then Notifiers::Discord.new(self)
    when 'teams' then Notifiers::Teams.new(self)
    when 'opsgenie' then Notifiers::Opsgenie.new(self)
    end
  end
  
  def send_notification!(alert:, notification_type:)
    notifier.send!(alert: alert, notification_type: notification_type)
  end
  
  def test!
    result = notifier.test!
    update!(
      last_tested_at: Time.current,
      last_test_status: result[:success] ? 'success' : 'failed',
      verified: result[:success]
    )
    result
  end
  
  private
  
  def generate_slug
    self.slug ||= name&.parameterize
  end
end

# app/models/incident.rb

class Incident < ApplicationRecord
  belongs_to :project
  has_many :alerts, dependent: :nullify
  has_many :notifications, dependent: :destroy
  
  validates :title, presence: true
  validates :status, inclusion: { in: %w[triggered acknowledged resolved] }
  validates :severity, inclusion: { in: %w[info warning critical] }
  
  scope :open, -> { where(status: %w[triggered acknowledged]) }
  scope :resolved, -> { where(status: 'resolved') }
  scope :by_severity, ->(sev) { where(severity: sev) }
  scope :recent, -> { order(triggered_at: :desc) }
  
  def acknowledge!(by:)
    return if status == 'resolved'
    
    update!(
      status: 'acknowledged',
      acknowledged_at: Time.current,
      acknowledged_by: by
    )
    
    add_timeline_event(type: 'acknowledged', by: by)
  end
  
  def resolve!(by: nil, note: nil)
    update!(
      status: 'resolved',
      resolved_at: Time.current,
      resolved_by: by,
      resolution_note: note
    )
    
    add_timeline_event(type: 'resolved', by: by, message: note)
  end
  
  def add_timeline_event(type:, message: nil, by: nil, data: {})
    event = {
      at: Time.current.iso8601,
      type: type,
      message: message,
      by: by
    }.merge(data).compact
    
    update!(timeline: timeline + [event])
  end
  
  def duration
    end_time = resolved_at || Time.current
    end_time - triggered_at
  end
end
```

---

## Services

```ruby
# app/services/rule_evaluator.rb

class RuleEvaluator
  def initialize(rule)
    @rule = rule
    @project = rule.project
  end
  
  def evaluate
    data_source = get_data_source
    
    case @rule.rule_type
    when 'threshold'
      evaluate_threshold(data_source)
    when 'anomaly'
      evaluate_anomaly(data_source)
    when 'absence'
      evaluate_absence(data_source)
    when 'composite'
      evaluate_composite
    end
  end
  
  private
  
  def get_data_source
    case @rule.source
    when 'flux' then DataSources::Flux.new(@project)
    when 'pulse' then DataSources::Pulse.new(@project)
    when 'reflex' then DataSources::Reflex.new(@project)
    when 'recall' then DataSources::Recall.new(@project)
    end
  end
  
  def evaluate_threshold(data_source)
    value = data_source.query(
      name: @rule.source_name,
      aggregation: @rule.aggregation,
      window: @rule.window,
      query: @rule.query,
      group_by: @rule.group_by
    )
    
    triggered = compare(value, @rule.operator, @rule.threshold)
    
    {
      state: triggered ? 'firing' : 'ok',
      value: value,
      threshold: @rule.threshold,
      fingerprint: generate_fingerprint(value),
      labels: @rule.group_by.present? ? value[:labels] : {}
    }
  end
  
  def evaluate_anomaly(data_source)
    current = data_source.query(
      name: @rule.source_name,
      aggregation: 'avg',
      window: @rule.window,
      query: @rule.query
    )
    
    baseline = data_source.baseline(
      name: @rule.source_name,
      window: @rule.baseline_window
    )
    
    deviation = calculate_deviation(current, baseline)
    threshold = 10.0 / @rule.sensitivity  # Higher sensitivity = lower threshold
    
    triggered = deviation.abs > threshold
    
    {
      state: triggered ? 'firing' : 'ok',
      value: current,
      expected: baseline[:mean],
      deviation: deviation,
      fingerprint: generate_fingerprint(current),
      labels: {}
    }
  end
  
  def evaluate_absence(data_source)
    last_data = data_source.last_data_point(
      name: @rule.source_name,
      query: @rule.query
    )
    
    interval = parse_interval(@rule.expected_interval)
    triggered = last_data.nil? || last_data[:timestamp] < interval.ago
    
    {
      state: triggered ? 'firing' : 'ok',
      value: nil,
      last_seen: last_data&.dig(:timestamp),
      fingerprint: generate_fingerprint(nil),
      labels: {}
    }
  end
  
  def evaluate_composite
    results = @rule.composite_rules.map do |sub_rule|
      sub_evaluator = RuleEvaluator.new(
        AlertRule.new(sub_rule.merge(project: @project))
      )
      sub_evaluator.evaluate
    end
    
    all_firing = results.all? { |r| r[:state] == 'firing' }
    any_firing = results.any? { |r| r[:state] == 'firing' }
    
    triggered = @rule.composite_operator == 'and' ? all_firing : any_firing
    
    {
      state: triggered ? 'firing' : 'ok',
      sub_results: results,
      fingerprint: generate_fingerprint(results),
      labels: {}
    }
  end
  
  def compare(value, operator, threshold)
    case operator
    when 'gt' then value > threshold
    when 'gte' then value >= threshold
    when 'lt' then value < threshold
    when 'lte' then value <= threshold
    when 'eq' then value == threshold
    when 'neq' then value != threshold
    else false
    end
  end
  
  def calculate_deviation(current, baseline)
    return 0 if baseline[:stddev].zero?
    (current - baseline[:mean]) / baseline[:stddev]
  end
  
  def generate_fingerprint(value)
    Digest::SHA256.hexdigest("#{@rule.id}:#{@rule.group_by}:#{value}")
  end
  
  def parse_interval(interval)
    match = interval.match(/^(\d+)(m|h|d)$/)
    return 5.minutes unless match
    
    value = match[1].to_i
    case match[2]
    when 'm' then value.minutes
    when 'h' then value.hours
    when 'd' then value.days
    end
  end
end

# app/services/alert_manager.rb

class AlertManager
  def initialize(rule)
    @rule = rule
    @project = rule.project
  end
  
  def process(result)
    fingerprint = result[:fingerprint]
    alert = find_or_initialize_alert(fingerprint)
    
    case result[:state]
    when 'firing'
      handle_firing(alert, result)
    when 'ok'
      handle_ok(alert, result)
    end
  end
  
  private
  
  def find_or_initialize_alert(fingerprint)
    @rule.alerts.find_or_initialize_by(fingerprint: fingerprint) do |a|
      a.project = @project
      a.state = 'pending'
      a.started_at = Time.current
    end
  end
  
  def handle_firing(alert, result)
    alert.current_value = result[:value]
    alert.threshold_value = result[:threshold]
    alert.labels = result[:labels]
    
    case alert.state
    when 'pending'
      if pending_long_enough?(alert)
        alert.fire!
      else
        alert.save!
      end
    when 'firing'
      alert.update!(last_fired_at: Time.current)
    when 'resolved', nil
      # New alert
      alert.state = 'pending'
      alert.started_at = Time.current
      alert.resolved_at = nil
      alert.acknowledged = false
      alert.save!
    end
  end
  
  def handle_ok(alert, result)
    return unless alert.persisted?
    
    case alert.state
    when 'firing'
      if ok_long_enough?(alert)
        alert.resolve!
      end
    when 'pending'
      alert.destroy!
    end
  end
  
  def pending_long_enough?(alert)
    return true if @rule.pending_period.zero?
    alert.started_at < @rule.pending_period.seconds.ago
  end
  
  def ok_long_enough?(alert)
    # Check if the alert has been OK for the resolve period
    recent_history = AlertHistory
      .where(alert_rule: @rule, fingerprint: alert.fingerprint)
      .where('timestamp > ?', @rule.resolve_period.seconds.ago)
      .pluck(:state)
    
    recent_history.all? { |s| s == 'ok' }
  end
end

# app/services/incident_manager.rb

class IncidentManager
  def initialize(alert)
    @alert = alert
    @rule = alert.alert_rule
    @project = alert.project
  end
  
  def fire!
    incident = find_or_create_incident
    @alert.update!(incident: incident)
    
    incident.add_timeline_event(
      type: 'alert_fired',
      message: "Alert fired: #{@rule.name}",
      data: { alert_id: @alert.id, value: @alert.current_value }
    )
    
    incident
  end
  
  def resolve!
    return unless @alert.incident
    
    @alert.incident.add_timeline_event(
      type: 'alert_resolved',
      message: "Alert resolved: #{@rule.name}",
      data: { alert_id: @alert.id }
    )
    
    # Check if all alerts for this incident are resolved
    if @alert.incident.alerts.firing.none?
      @alert.incident.resolve!
    end
  end
  
  private
  
  def find_or_create_incident
    # Find existing open incident for this rule
    existing = Incident.open.joins(:alerts).where(alerts: { alert_rule_id: @rule.id }).first
    return existing if existing
    
    # Create new incident
    Incident.create!(
      project: @project,
      title: @rule.name,
      summary: @rule.condition_description,
      severity: @rule.severity,
      status: 'triggered',
      triggered_at: Time.current,
      timeline: [{
        at: Time.current.iso8601,
        type: 'triggered',
        message: "Incident triggered by #{@rule.name}"
      }]
    )
  end
end
```

---

## Notifiers

```ruby
# app/services/notifiers/base.rb

module Notifiers
  class Base
    def initialize(channel)
      @channel = channel
      @config = channel.config.with_indifferent_access
    end
    
    def send!(alert:, notification_type:)
      payload = build_payload(alert, notification_type)
      
      begin
        response = deliver!(payload)
        record_success!(alert, notification_type, payload, response)
        { success: true, response: response }
      rescue => e
        record_failure!(alert, notification_type, payload, e)
        { success: false, error: e.message }
      end
    end
    
    def test!
      payload = build_test_payload
      
      begin
        response = deliver!(payload)
        { success: true, response: response }
      rescue => e
        { success: false, error: e.message }
      end
    end
    
    protected
    
    def deliver!(payload)
      raise NotImplementedError
    end
    
    def build_payload(alert, notification_type)
      raise NotImplementedError
    end
    
    def build_test_payload
      raise NotImplementedError
    end
    
    private
    
    def record_success!(alert, notification_type, payload, response)
      @channel.increment!(:success_count)
      @channel.update!(last_used_at: Time.current)
      
      Notification.create!(
        project: @channel.project,
        alert: alert,
        notification_channel: @channel,
        notification_type: notification_type.to_s,
        status: 'sent',
        payload: payload,
        response: response,
        sent_at: Time.current
      )
    end
    
    def record_failure!(alert, notification_type, payload, error)
      @channel.increment!(:failure_count)
      
      Notification.create!(
        project: @channel.project,
        alert: alert,
        notification_channel: @channel,
        notification_type: notification_type.to_s,
        status: 'failed',
        payload: payload,
        error_message: error.message
      )
    end
  end
end

# app/services/notifiers/slack.rb

module Notifiers
  class Slack < Base
    protected
    
    def deliver!(payload)
      response = HTTP.post(@config[:webhook_url], json: payload)
      raise "Slack error: #{response.body}" unless response.status.success?
      { status: response.status.code }
    end
    
    def build_payload(alert, notification_type)
      rule = alert.alert_rule
      
      color = case rule.severity
              when 'critical' then '#FF0000'
              when 'warning' then '#FFA500'
              else '#36A2EB'
              end
      
      status_emoji = notification_type == :alert_fired ? '🔴' : '🟢'
      status_text = notification_type == :alert_fired ? 'FIRING' : 'RESOLVED'
      
      {
        channel: @config[:channel],
        username: 'Brainz Lab Signal',
        icon_emoji: ':bell:',
        attachments: [{
          color: color,
          title: "#{status_emoji} [#{status_text}] #{rule.name}",
          text: rule.condition_description,
          fields: [
            { title: 'Severity', value: rule.severity.upcase, short: true },
            { title: 'Value', value: alert.current_value.to_s, short: true },
            { title: 'Duration', value: alert.duration_human, short: true },
            { title: 'Source', value: "#{rule.source}/#{rule.source_name}", short: true }
          ],
          footer: 'Brainz Lab Signal',
          ts: Time.current.to_i,
          actions: [
            {
              type: 'button',
              text: 'View Alert',
              url: "https://signal.brainzlab.ai/alerts/#{alert.id}"
            },
            {
              type: 'button',
              text: 'Acknowledge',
              url: "https://signal.brainzlab.ai/alerts/#{alert.id}/acknowledge"
            }
          ]
        }]
      }
    end
    
    def build_test_payload
      {
        channel: @config[:channel],
        username: 'Brainz Lab Signal',
        icon_emoji: ':bell:',
        text: '✅ Test notification from Brainz Lab Signal. Your Slack integration is working!'
      }
    end
  end
end

# app/services/notifiers/pagerduty.rb

module Notifiers
  class Pagerduty < Base
    EVENTS_API = 'https://events.pagerduty.com/v2/enqueue'.freeze
    
    protected
    
    def deliver!(payload)
      response = HTTP.post(EVENTS_API, json: payload)
      raise "PagerDuty error: #{response.body}" unless response.status.success?
      JSON.parse(response.body)
    end
    
    def build_payload(alert, notification_type)
      rule = alert.alert_rule
      
      event_action = notification_type == :alert_fired ? 'trigger' : 'resolve'
      severity = @config.dig(:severity_map, rule.severity) || rule.severity
      
      {
        routing_key: @config[:routing_key],
        event_action: event_action,
        dedup_key: alert.fingerprint,
        payload: {
          summary: "[#{rule.severity.upcase}] #{rule.name}: #{rule.condition_description}",
          source: 'Brainz Lab Signal',
          severity: severity,
          timestamp: Time.current.iso8601,
          custom_details: {
            rule_id: rule.id,
            rule_name: rule.name,
            current_value: alert.current_value,
            threshold: alert.threshold_value,
            duration: alert.duration_human,
            labels: alert.labels
          }
        },
        links: [
          {
            href: "https://signal.brainzlab.ai/alerts/#{alert.id}",
            text: 'View in Brainz Lab'
          }
        ]
      }
    end
    
    def build_test_payload
      {
        routing_key: @config[:routing_key],
        event_action: 'trigger',
        dedup_key: "test-#{SecureRandom.hex(8)}",
        payload: {
          summary: 'Test alert from Brainz Lab Signal',
          source: 'Brainz Lab Signal',
          severity: 'info',
          timestamp: Time.current.iso8601
        }
      }
    end
  end
end

# app/services/notifiers/webhook.rb

module Notifiers
  class Webhook < Base
    protected
    
    def deliver!(payload)
      method = (@config[:method] || 'POST').upcase
      headers = (@config[:headers] || {}).merge('Content-Type' => 'application/json')
      
      response = HTTP.headers(headers).send(method.downcase, @config[:url], json: payload)
      raise "Webhook error: #{response.status}" unless response.status.success?
      
      { status: response.status.code, body: response.body.to_s[0..500] }
    end
    
    def build_payload(alert, notification_type)
      rule = alert.alert_rule
      
      if @config[:template].present?
        # Custom template
        render_template(@config[:template], alert, notification_type)
      else
        # Default payload
        {
          event_type: notification_type.to_s,
          timestamp: Time.current.iso8601,
          alert: {
            id: alert.id,
            fingerprint: alert.fingerprint,
            state: alert.state,
            started_at: alert.started_at.iso8601,
            resolved_at: alert.resolved_at&.iso8601,
            current_value: alert.current_value,
            threshold_value: alert.threshold_value,
            duration_seconds: alert.duration.to_i,
            labels: alert.labels,
            acknowledged: alert.acknowledged
          },
          rule: {
            id: rule.id,
            name: rule.name,
            severity: rule.severity,
            source: rule.source,
            source_name: rule.source_name,
            condition: rule.condition_description
          },
          project_id: alert.project_id
        }
      end
    end
    
    def build_test_payload
      {
        event_type: 'test',
        timestamp: Time.current.iso8601,
        message: 'Test webhook from Brainz Lab Signal'
      }
    end
    
    private
    
    def render_template(template, alert, notification_type)
      # Simple template rendering with {{variable}} syntax
      rule = alert.alert_rule
      
      result = template.dup
      result.gsub!('{{alert.id}}', alert.id.to_s)
      result.gsub!('{{alert.state}}', alert.state)
      result.gsub!('{{alert.value}}', alert.current_value.to_s)
      result.gsub!('{{rule.name}}', rule.name)
      result.gsub!('{{rule.severity}}', rule.severity)
      result.gsub!('{{notification_type}}', notification_type.to_s)
      
      JSON.parse(result)
    end
  end
end

# app/services/notifiers/email.rb

module Notifiers
  class Email < Base
    protected
    
    def deliver!(payload)
      AlertMailer.alert_notification(
        to: @config[:to],
        subject: payload[:subject],
        body: payload[:body],
        alert_id: payload[:alert_id]
      ).deliver_now
      
      { delivered: true }
    end
    
    def build_payload(alert, notification_type)
      rule = alert.alert_rule
      status = notification_type == :alert_fired ? 'FIRING' : 'RESOLVED'
      
      subject_prefix = @config[:subject_prefix] || '[Brainz Lab Signal]'
      
      {
        subject: "#{subject_prefix} [#{status}] #{rule.name}",
        body: build_email_body(alert, notification_type),
        alert_id: alert.id
      }
    end
    
    def build_test_payload
      {
        subject: '[Brainz Lab Signal] Test Notification',
        body: 'This is a test notification from Brainz Lab Signal. Your email integration is working!',
        alert_id: nil
      }
    end
    
    private
    
    def build_email_body(alert, notification_type)
      rule = alert.alert_rule
      status = notification_type == :alert_fired ? 'FIRING' : 'RESOLVED'
      
      <<~BODY
        Alert Status: #{status}
        
        Rule: #{rule.name}
        Severity: #{rule.severity.upcase}
        Condition: #{rule.condition_description}
        
        Current Value: #{alert.current_value}
        Threshold: #{alert.threshold_value}
        Duration: #{alert.duration_human}
        
        Started: #{alert.started_at}
        #{alert.resolved_at ? "Resolved: #{alert.resolved_at}" : ''}
        
        View Alert: https://signal.brainzlab.ai/alerts/#{alert.id}
        
        ---
        Brainz Lab Signal
      BODY
    end
  end
end
```

---

## API Controllers

```ruby
# app/controllers/api/v1/alerts_controller.rb

module Api
  module V1
    class AlertsController < BaseController
      before_action :require_scope!('signal')
      
      def index
        alerts = @project.alerts
          .includes(:alert_rule, :incident)
          .order(started_at: :desc)
        
        alerts = alerts.where(state: params[:state]) if params[:state].present?
        alerts = alerts.joins(:alert_rule).where(alert_rules: { severity: params[:severity] }) if params[:severity].present?
        alerts = alerts.unacknowledged if params[:unacknowledged] == 'true'
        
        alerts = alerts.limit(params[:limit] || 50)
        
        render json: {
          alerts: alerts.map { |a| serialize_alert(a) },
          total: alerts.count
        }
      end
      
      def show
        alert = @project.alerts.find(params[:id])
        render json: serialize_alert(alert, full: true)
      end
      
      def acknowledge
        alert = @project.alerts.find(params[:id])
        alert.acknowledge!(
          by: params[:by] || 'API',
          note: params[:note]
        )
        
        render json: serialize_alert(alert)
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
          data[:incident] = alert.incident&.as_json(only: [:id, :title, :status])
          data[:notifications] = alert.notifications.order(created_at: :desc).limit(10).as_json
          data[:rule_full] = alert.alert_rule.as_json(except: [:project_id])
        end
        
        data
      end
    end
  end
end

# app/controllers/api/v1/rules_controller.rb

module Api
  module V1
    class RulesController < BaseController
      before_action :require_scope!('signal')
      before_action :set_rule, only: [:show, :update, :destroy, :mute, :unmute, :test]
      
      def index
        rules = @project.alert_rules.order(created_at: :desc)
        rules = rules.by_source(params[:source]) if params[:source].present?
        rules = rules.enabled if params[:enabled] == 'true'
        
        render json: {
          rules: rules.map { |r| serialize_rule(r) }
        }
      end
      
      def show
        render json: serialize_rule(@rule, full: true)
      end
      
      def create
        rule = @project.alert_rules.build(rule_params)
        
        if rule.save
          render json: serialize_rule(rule), status: :created
        else
          render json: { errors: rule.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def update
        if @rule.update(rule_params)
          render json: serialize_rule(@rule)
        else
          render json: { errors: @rule.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def destroy
        @rule.destroy!
        head :no_content
      end
      
      def mute
        @rule.mute!(
          until_time: params[:until] ? Time.parse(params[:until]) : nil,
          reason: params[:reason]
        )
        render json: serialize_rule(@rule)
      end
      
      def unmute
        @rule.unmute!
        render json: serialize_rule(@rule)
      end
      
      def test
        result = @rule.evaluate!
        render json: {
          rule: serialize_rule(@rule),
          result: result
        }
      end
      
      private
      
      def set_rule
        @rule = @project.alert_rules.find(params[:id])
      end
      
      def rule_params
        params.require(:rule).permit(
          :name, :description, :source, :source_type, :source_name,
          :rule_type, :operator, :threshold, :aggregation, :window,
          :sensitivity, :baseline_window, :expected_interval,
          :composite_operator, :severity, :evaluation_interval,
          :pending_period, :resolve_period, :enabled, :escalation_policy_id,
          query: {}, group_by: [], notify_channels: [], labels: {},
          annotations: {}, composite_rules: []
        )
      end
      
      def serialize_rule(rule, full: false)
        data = {
          id: rule.id,
          name: rule.name,
          slug: rule.slug,
          source: rule.source,
          source_name: rule.source_name,
          rule_type: rule.rule_type,
          condition: rule.condition_description,
          severity: rule.severity,
          enabled: rule.enabled,
          muted: rule.muted?,
          last_state: rule.last_state,
          last_evaluated_at: rule.last_evaluated_at,
          firing_alerts_count: rule.alerts.firing.count
        }
        
        if full
          data.merge!(
            description: rule.description,
            operator: rule.operator,
            threshold: rule.threshold,
            aggregation: rule.aggregation,
            window: rule.window,
            query: rule.query,
            group_by: rule.group_by,
            notify_channels: rule.notify_channels,
            evaluation_interval: rule.evaluation_interval,
            pending_period: rule.pending_period,
            resolve_period: rule.resolve_period,
            labels: rule.labels,
            annotations: rule.annotations
          )
        end
        
        data
      end
    end
  end
end

# app/controllers/api/v1/channels_controller.rb

module Api
  module V1
    class ChannelsController < BaseController
      before_action :require_scope!('signal')
      before_action :set_channel, only: [:show, :update, :destroy, :test]
      
      def index
        channels = @project.notification_channels.order(:name)
        render json: {
          channels: channels.map { |c| serialize_channel(c) }
        }
      end
      
      def show
        render json: serialize_channel(@channel, full: true)
      end
      
      def create
        channel = @project.notification_channels.build(channel_params)
        
        if channel.save
          render json: serialize_channel(channel), status: :created
        else
          render json: { errors: channel.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def update
        if @channel.update(channel_params)
          render json: serialize_channel(@channel)
        else
          render json: { errors: @channel.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      def destroy
        @channel.destroy!
        head :no_content
      end
      
      def test
        result = @channel.test!
        render json: {
          success: result[:success],
          error: result[:error],
          channel: serialize_channel(@channel)
        }
      end
      
      private
      
      def set_channel
        @channel = @project.notification_channels.find(params[:id])
      end
      
      def channel_params
        params.require(:channel).permit(
          :name, :channel_type, :enabled,
          config: {}
        )
      end
      
      def serialize_channel(channel, full: false)
        data = {
          id: channel.id,
          name: channel.name,
          slug: channel.slug,
          channel_type: channel.channel_type,
          enabled: channel.enabled,
          verified: channel.verified,
          last_used_at: channel.last_used_at,
          success_count: channel.success_count,
          failure_count: channel.failure_count
        }
        
        if full
          # Mask sensitive config values
          data[:config] = mask_config(channel.config)
        end
        
        data
      end
      
      def mask_config(config)
        config.transform_values do |v|
          v.is_a?(String) && v.length > 8 ? "#{v[0..3]}...#{v[-4..]}" : v
        end
      end
    end
  end
end
```

---

## MCP Tools

```ruby
# app/services/mcp/tools/signal_list_alerts.rb

module Mcp
  module Tools
    class SignalListAlerts < Base
      DESCRIPTION = "List active alerts and their status"
      SCHEMA = {
        type: "object",
        properties: {
          state: { type: "string", enum: ["firing", "pending", "resolved"], description: "Filter by state" },
          severity: { type: "string", enum: ["info", "warning", "critical"], description: "Filter by severity" },
          limit: { type: "integer", default: 20 }
        }
      }
      
      def call(args)
        alerts = @project.alerts
          .includes(:alert_rule)
          .order(started_at: :desc)
        
        alerts = alerts.where(state: args[:state]) if args[:state]
        alerts = alerts.joins(:alert_rule).where(alert_rules: { severity: args[:severity] }) if args[:severity]
        alerts = alerts.limit(args[:limit] || 20)
        
        {
          alerts: alerts.map do |a|
            {
              id: a.id,
              rule: a.alert_rule.name,
              severity: a.alert_rule.severity,
              state: a.state,
              value: a.current_value,
              started: a.started_at.iso8601,
              duration: a.duration_human,
              acknowledged: a.acknowledged
            }
          end,
          summary: {
            firing: @project.alerts.firing.count,
            pending: @project.alerts.pending.count,
            critical: @project.alerts.joins(:alert_rule).where(alert_rules: { severity: 'critical' }).firing.count
          }
        }
      end
    end
    
    # app/services/mcp/tools/signal_acknowledge.rb
    
    class SignalAcknowledge < Base
      DESCRIPTION = "Acknowledge an alert"
      SCHEMA = {
        type: "object",
        properties: {
          alert_id: { type: "string", description: "Alert ID to acknowledge" },
          note: { type: "string", description: "Optional acknowledgment note" }
        },
        required: ["alert_id"]
      }
      
      def call(args)
        alert = @project.alerts.find(args[:alert_id])
        alert.acknowledge!(by: "MCP", note: args[:note])
        
        {
          success: true,
          alert: {
            id: alert.id,
            rule: alert.alert_rule.name,
            acknowledged: true,
            acknowledged_at: alert.acknowledged_at.iso8601
          }
        }
      end
    end
    
    # app/services/mcp/tools/signal_create_rule.rb
    
    class SignalCreateRule < Base
      DESCRIPTION = "Create a new alert rule"
      SCHEMA = {
        type: "object",
        properties: {
          name: { type: "string", description: "Rule name" },
          source: { type: "string", enum: ["flux", "pulse", "reflex", "recall"] },
          source_name: { type: "string", description: "Metric or event name to monitor" },
          operator: { type: "string", enum: ["gt", "gte", "lt", "lte", "eq", "neq"] },
          threshold: { type: "number" },
          window: { type: "string", default: "5m", description: "Time window (1m, 5m, 15m, 1h)" },
          severity: { type: "string", enum: ["info", "warning", "critical"], default: "warning" }
        },
        required: ["name", "source", "source_name", "operator", "threshold"]
      }
      
      def call(args)
        rule = @project.alert_rules.create!(
          name: args[:name],
          source: args[:source],
          source_name: args[:source_name],
          rule_type: 'threshold',
          operator: args[:operator],
          threshold: args[:threshold],
          aggregation: 'avg',
          window: args[:window] || '5m',
          severity: args[:severity] || 'warning',
          enabled: true
        )
        
        {
          success: true,
          rule: {
            id: rule.id,
            name: rule.name,
            condition: rule.condition_description,
            severity: rule.severity
          }
        }
      end
    end
    
    # app/services/mcp/tools/signal_mute.rb
    
    class SignalMute < Base
      DESCRIPTION = "Mute an alert rule"
      SCHEMA = {
        type: "object",
        properties: {
          rule_id: { type: "string", description: "Rule ID to mute" },
          duration: { type: "string", description: "Mute duration (1h, 4h, 24h, 7d)", default: "1h" },
          reason: { type: "string", description: "Reason for muting" }
        },
        required: ["rule_id"]
      }
      
      def call(args)
        rule = @project.alert_rules.find(args[:rule_id])
        
        until_time = parse_duration(args[:duration] || '1h')
        rule.mute!(until_time: until_time, reason: args[:reason])
        
        {
          success: true,
          rule: rule.name,
          muted_until: until_time.iso8601,
          reason: args[:reason]
        }
      end
      
      private
      
      def parse_duration(duration)
        match = duration.match(/^(\d+)(h|d)$/)
        return 1.hour.from_now unless match
        
        value = match[1].to_i
        case match[2]
        when 'h' then value.hours.from_now
        when 'd' then value.days.from_now
        end
      end
    end
    
    # app/services/mcp/tools/signal_incidents.rb
    
    class SignalIncidents < Base
      DESCRIPTION = "List incidents"
      SCHEMA = {
        type: "object",
        properties: {
          status: { type: "string", enum: ["triggered", "acknowledged", "resolved"] },
          limit: { type: "integer", default: 10 }
        }
      }
      
      def call(args)
        incidents = @project.incidents.order(triggered_at: :desc)
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
```

---

## Jobs

```ruby
# app/jobs/rule_evaluation_job.rb

class RuleEvaluationJob < ApplicationJob
  queue_as :alerts
  
  def perform(rule_id = nil)
    if rule_id
      # Evaluate single rule
      rule = AlertRule.find(rule_id)
      rule.evaluate! if rule.enabled? && !rule.muted?
    else
      # Evaluate all active rules
      AlertRule.active.find_each do |rule|
        rule.evaluate!
      rescue => e
        Rails.logger.error("Error evaluating rule #{rule.id}: #{e.message}")
      end
    end
  end
end

# app/jobs/notification_job.rb

class NotificationJob < ApplicationJob
  queue_as :notifications
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  
  def perform(channel_id:, alert_id:, notification_type:)
    channel = NotificationChannel.find(channel_id)
    alert = Alert.find(alert_id)
    
    return unless channel.enabled?
    return if alert.alert_rule.muted?
    
    # Check maintenance windows
    return if in_maintenance_window?(alert)
    
    channel.send_notification!(
      alert: alert,
      notification_type: notification_type.to_sym
    )
  end
  
  private
  
  def in_maintenance_window?(alert)
    MaintenanceWindow
      .where(project: alert.project, active: true)
      .where('starts_at <= ? AND ends_at >= ?', Time.current, Time.current)
      .where('rule_ids = ? OR ? = ANY(rule_ids)', '[]', alert.alert_rule_id)
      .exists?
  end
end

# app/jobs/escalation_job.rb

class EscalationJob < ApplicationJob
  queue_as :alerts
  
  def perform(alert_id:, step_index:)
    alert = Alert.find(alert_id)
    return if alert.state != 'firing' || alert.acknowledged
    
    policy = alert.alert_rule.escalation_policy
    return unless policy
    
    step = policy.steps[step_index]
    return unless step
    
    # Send notifications for this step
    step['channels'].each do |channel_id|
      NotificationJob.perform_later(
        channel_id: channel_id,
        alert_id: alert.id,
        notification_type: 'escalation'
      )
    end
    
    # Schedule next step if exists
    next_step = policy.steps[step_index + 1]
    if next_step
      EscalationJob.set(wait: next_step['delay_minutes'].minutes).perform_later(
        alert_id: alert.id,
        step_index: step_index + 1
      )
    elsif policy.repeat
      # Repeat from beginning
      EscalationJob.set(wait: policy.repeat_after_minutes.minutes).perform_later(
        alert_id: alert.id,
        step_index: 0
      )
    end
  end
end
```

---

## SDK Integration

```ruby
# In brainzlab-sdk gem

module BrainzLab
  module Signal
    class << self
      # Manually trigger an alert (for custom alerting logic)
      def trigger(name, value:, severity: 'warning', labels: {})
        client.post('/api/v1/alerts/trigger', {
          name: name,
          value: value,
          severity: severity,
          labels: labels
        })
      end
      
      # Resolve a manually triggered alert
      def resolve(name, labels: {})
        client.post('/api/v1/alerts/resolve', {
          name: name,
          labels: labels
        })
      end
      
      # Send a test notification to a channel
      def test_channel(channel_slug)
        client.post("/api/v1/channels/#{channel_slug}/test")
      end
      
      private
      
      def client
        @client ||= Client.new(
          url: BrainzLab.config.signal_url || 'https://signal.brainzlab.ai',
          api_key: BrainzLab.config.api_key
        )
      end
    end
  end
end
```

---

## Configuration

```yaml
# config/signal.yml

# Evaluation intervals
evaluation:
  default_interval: 60          # seconds
  max_concurrent_evaluations: 50
  
# Notification settings
notifications:
  max_retries: 5
  retry_backoff: exponential
  rate_limits:
    slack: 1                    # per second
    pagerduty: 10               # per second
    email: 1                    # per second
    webhook: 10                 # per second

# Alert settings
alerts:
  default_pending_period: 0     # seconds
  default_resolve_period: 300   # seconds
  max_alerts_per_rule: 1000

# Incident settings
incidents:
  auto_resolve_after: 24.hours
  group_window: 5.minutes       # Group alerts into same incident

# History retention
history:
  retention_days: 90
```

---

## Routes

```ruby
# config/routes.rb

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Alerts
      resources :alerts, only: [:index, :show] do
        member do
          post :acknowledge
        end
      end
      
      # Alert Rules
      resources :rules do
        member do
          post :mute
          post :unmute
          post :test
        end
      end
      
      # Notification Channels
      resources :channels do
        member do
          post :test
        end
      end
      
      # Incidents
      resources :incidents, only: [:index, :show] do
        member do
          post :acknowledge
          post :resolve
        end
      end
      
      # Escalation Policies
      resources :escalation_policies
      
      # On-call Schedules
      resources :on_call_schedules do
        member do
          get :current
        end
      end
      
      # Maintenance Windows
      resources :maintenance_windows
      
      # Manual alert trigger/resolve
      post 'alerts/trigger', to: 'alerts#trigger'
      post 'alerts/resolve', to: 'alerts#resolve_by_name'
    end
  end
  
  # MCP
  namespace :mcp do
    post 'tools/:tool', to: 'tools#execute'
    get 'tools', to: 'tools#list'
  end
  
  # Webhooks (incoming from other services)
  namespace :webhooks do
    post 'flux', to: 'flux#create'      # Flux anomaly notifications
    post 'reflex', to: 'reflex#create'  # Error notifications
    post 'pulse', to: 'pulse#create'    # APM notifications
  end
  
  # Dashboard
  root 'dashboard#index'
end
```

---

## Summary

### Signal Provides

| Feature | Description |
|---------|-------------|
| **Alert Rules** | Threshold, anomaly, absence, composite |
| **Data Sources** | Flux, Pulse, Reflex, Recall integration |
| **Notifications** | Slack, PagerDuty, Email, Webhook, Discord, Teams, Opsgenie |
| **Incidents** | Group alerts, timeline, resolution tracking |
| **Escalations** | Multi-step escalation policies |
| **On-call** | Schedules and rotation management |
| **Maintenance** | Scheduled muting windows |

### MCP Tools

| Tool | Description |
|------|-------------|
| `signal_list_alerts` | List active alerts |
| `signal_acknowledge` | Acknowledge an alert |
| `signal_create_rule` | Create alert rule |
| `signal_mute` | Mute a rule |
| `signal_incidents` | List incidents |

### SDK Methods

```ruby
BrainzLab::Signal.trigger(name, value:, severity:)  # Manual trigger
BrainzLab::Signal.resolve(name)                      # Manual resolve
BrainzLab::Signal.test_channel(slug)                 # Test channel
```

### API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /api/v1/alerts` | List alerts |
| `POST /api/v1/alerts/:id/acknowledge` | Acknowledge |
| `GET /api/v1/rules` | List rules |
| `POST /api/v1/rules` | Create rule |
| `POST /api/v1/rules/:id/mute` | Mute rule |
| `GET /api/v1/channels` | List channels |
| `POST /api/v1/channels/:id/test` | Test channel |
| `GET /api/v1/incidents` | List incidents |

---

## Build Order

```
PARALLEL BUILD:

Platform ─────────────┐
                      ├──▶ Integration ──▶ Launch
Signal ───────────────┤
                      │
Flux ─────────────────┘

Week 1-2: All three in parallel
Week 3: Integration + testing
Week 4: Launch
```

---

*Signal = Know before your users do! 🔔*
