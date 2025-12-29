# frozen_string_literal: true

puts "Seeding Signal development data..."

# Create a development project
# Use a fixed UUID for idempotent seeding
DEV_PROJECT_UUID = "00000000-0000-0000-0000-000000000001"

project = Project.find_or_create_by!(platform_project_id: DEV_PROJECT_UUID) do |p|
  p.name = "Demo App"
end

puts "Created project: #{project.name}"

# ============================================================================
# Notification Channels
# ============================================================================

puts "\nCreating notification channels..."

slack_channel = NotificationChannel.find_or_create_by!(
  project_id: project.id,
  slug: "slack-alerts"
) do |c|
  c.name = "Slack Alerts"
  c.channel_type = "slack"
  c.enabled = true
  c.verified = true
  c.config = {
    webhook_url: "https://hooks.slack.com/services/EXAMPLE/WEBHOOK",
    channel: "#alerts"
  }
end

email_channel = NotificationChannel.find_or_create_by!(
  project_id: project.id,
  slug: "email-oncall"
) do |c|
  c.name = "Email On-Call"
  c.channel_type = "email"
  c.enabled = true
  c.verified = true
  c.config = {
    recipients: ["oncall@example.com", "alerts@example.com"]
  }
end

webhook_channel = NotificationChannel.find_or_create_by!(
  project_id: project.id,
  slug: "webhook-integration"
) do |c|
  c.name = "Webhook Integration"
  c.channel_type = "webhook"
  c.enabled = true
  c.verified = false
  c.config = {
    url: "https://api.example.com/webhooks/alerts",
    method: "POST",
    headers: { "X-Alert-Source" => "signal" }
  }
end

pagerduty_channel = NotificationChannel.find_or_create_by!(
  project_id: project.id,
  slug: "pagerduty-critical"
) do |c|
  c.name = "PagerDuty Critical"
  c.channel_type = "pagerduty"
  c.enabled = false
  c.verified = false
  c.config = {
    routing_key: "EXAMPLE_ROUTING_KEY",
    severity: "critical"
  }
end

puts "  Created #{NotificationChannel.for_project(project.id).count} notification channels"

# ============================================================================
# Alert Rules - Threshold Type
# ============================================================================

puts "\nCreating alert rules..."

# High CPU Usage (Flux metrics)
AlertRule.find_or_create_by!(project_id: project.id, slug: "high-cpu-usage") do |r|
  r.name = "High CPU Usage"
  r.description = "Alert when CPU usage exceeds 80% for 5 minutes"
  r.source = "flux"
  r.source_type = "metric"
  r.source_name = "system.cpu.usage"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 80.0
  r.aggregation = "avg"
  r.window = "5m"
  r.severity = "warning"
  r.enabled = true
  r.evaluation_interval = 60
  r.pending_period = 60
  r.resolve_period = 300
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "infrastructure" }
  r.annotations = {
    runbook_url: "https://wiki.example.com/runbooks/high-cpu",
    dashboard_url: "https://dashboard.example.com/cpu"
  }
end

# Critical CPU Usage
AlertRule.find_or_create_by!(project_id: project.id, slug: "critical-cpu-usage") do |r|
  r.name = "Critical CPU Usage"
  r.description = "Alert when CPU usage exceeds 95% for 2 minutes"
  r.source = "flux"
  r.source_type = "metric"
  r.source_name = "system.cpu.usage"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 95.0
  r.aggregation = "avg"
  r.window = "2m"
  r.severity = "critical"
  r.enabled = true
  r.evaluation_interval = 30
  r.pending_period = 0
  r.resolve_period = 120
  r.notify_channels = [slack_channel.id, email_channel.id]
  r.labels = { service: "infrastructure", priority: "p1" }
end

# High Memory Usage
AlertRule.find_or_create_by!(project_id: project.id, slug: "high-memory-usage") do |r|
  r.name = "High Memory Usage"
  r.description = "Alert when memory usage exceeds 85%"
  r.source = "flux"
  r.source_type = "metric"
  r.source_name = "system.memory.usage"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 85.0
  r.aggregation = "avg"
  r.window = "5m"
  r.severity = "warning"
  r.enabled = true
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "infrastructure" }
end

# High Disk Usage
AlertRule.find_or_create_by!(project_id: project.id, slug: "high-disk-usage") do |r|
  r.name = "High Disk Usage"
  r.description = "Alert when disk usage exceeds 90%"
  r.source = "flux"
  r.source_type = "metric"
  r.source_name = "system.disk.usage"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 90.0
  r.aggregation = "max"
  r.window = "15m"
  r.severity = "warning"
  r.enabled = true
  r.notify_channels = [email_channel.id]
  r.labels = { service: "infrastructure" }
end

# ============================================================================
# Alert Rules - APM/Pulse
# ============================================================================

# Slow Response Time
AlertRule.find_or_create_by!(project_id: project.id, slug: "slow-response-time") do |r|
  r.name = "Slow Response Time"
  r.description = "Alert when P95 response time exceeds 500ms"
  r.source = "pulse"
  r.source_type = "metric"
  r.source_name = "http.response_time"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 500.0
  r.aggregation = "p95"
  r.window = "5m"
  r.severity = "warning"
  r.enabled = true
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "api" }
  r.query = { endpoint: "/api/*" }
end

# Critical Response Time
AlertRule.find_or_create_by!(project_id: project.id, slug: "critical-response-time") do |r|
  r.name = "Critical Response Time"
  r.description = "Alert when P99 response time exceeds 2 seconds"
  r.source = "pulse"
  r.source_type = "metric"
  r.source_name = "http.response_time"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 2000.0
  r.aggregation = "p99"
  r.window = "5m"
  r.severity = "critical"
  r.enabled = true
  r.notify_channels = [slack_channel.id, email_channel.id]
  r.labels = { service: "api", priority: "p1" }
end

# Low Apdex Score
AlertRule.find_or_create_by!(project_id: project.id, slug: "low-apdex-score") do |r|
  r.name = "Low Apdex Score"
  r.description = "Alert when Apdex score drops below 0.8"
  r.source = "pulse"
  r.source_type = "metric"
  r.source_name = "apdex.score"
  r.rule_type = "threshold"
  r.operator = "lt"
  r.threshold = 0.8
  r.aggregation = "avg"
  r.window = "15m"
  r.severity = "warning"
  r.enabled = true
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "api" }
end

# High Throughput (info)
AlertRule.find_or_create_by!(project_id: project.id, slug: "high-throughput") do |r|
  r.name = "High Throughput"
  r.description = "Informational alert when request rate exceeds 1000 rpm"
  r.source = "pulse"
  r.source_type = "metric"
  r.source_name = "http.requests.count"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 1000.0
  r.aggregation = "sum"
  r.window = "1m"
  r.severity = "info"
  r.enabled = true
  r.notify_channels = []
  r.labels = { service: "api" }
end

# ============================================================================
# Alert Rules - Error Tracking/Reflex
# ============================================================================

# High Error Rate
AlertRule.find_or_create_by!(project_id: project.id, slug: "high-error-rate") do |r|
  r.name = "High Error Rate"
  r.description = "Alert when error rate exceeds 5%"
  r.source = "reflex"
  r.source_type = "metric"
  r.source_name = "errors.rate"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 5.0
  r.aggregation = "avg"
  r.window = "5m"
  r.severity = "warning"
  r.enabled = true
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "application" }
end

# Critical Error Spike
AlertRule.find_or_create_by!(project_id: project.id, slug: "critical-error-spike") do |r|
  r.name = "Critical Error Spike"
  r.description = "Alert when error count exceeds 100 in 5 minutes"
  r.source = "reflex"
  r.source_type = "metric"
  r.source_name = "errors.count"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 100.0
  r.aggregation = "sum"
  r.window = "5m"
  r.severity = "critical"
  r.enabled = true
  r.notify_channels = [slack_channel.id, email_channel.id]
  r.labels = { service: "application", priority: "p1" }
end

# New Unresolved Errors
AlertRule.find_or_create_by!(project_id: project.id, slug: "new-unresolved-errors") do |r|
  r.name = "New Unresolved Errors"
  r.description = "Alert when new error groups are created"
  r.source = "reflex"
  r.source_type = "event"
  r.source_name = "error.new_group"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 0.0
  r.aggregation = "count"
  r.window = "15m"
  r.severity = "info"
  r.enabled = true
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "application" }
end

# ============================================================================
# Alert Rules - Log Monitoring/Recall
# ============================================================================

# Error Log Spike
AlertRule.find_or_create_by!(project_id: project.id, slug: "error-log-spike") do |r|
  r.name = "Error Log Spike"
  r.description = "Alert when error logs exceed 50 per minute"
  r.source = "recall"
  r.source_type = "log"
  r.source_name = "log.error"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 50.0
  r.aggregation = "count"
  r.window = "1m"
  r.severity = "warning"
  r.enabled = true
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "logs" }
  r.query = { level: "error" }
end

# Security Alert Pattern
AlertRule.find_or_create_by!(project_id: project.id, slug: "security-alert-pattern") do |r|
  r.name = "Security Alert Pattern"
  r.description = "Alert on suspicious log patterns (failed auth attempts)"
  r.source = "recall"
  r.source_type = "log"
  r.source_name = "log.security"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 10.0
  r.aggregation = "count"
  r.window = "5m"
  r.severity = "critical"
  r.enabled = true
  r.notify_channels = [slack_channel.id, email_channel.id]
  r.labels = { service: "security", priority: "p1" }
  r.query = { pattern: "failed_auth|unauthorized|suspicious" }
end

# ============================================================================
# Alert Rules - Anomaly Detection
# ============================================================================

# Traffic Anomaly
AlertRule.find_or_create_by!(project_id: project.id, slug: "traffic-anomaly") do |r|
  r.name = "Traffic Anomaly"
  r.description = "Detect unusual traffic patterns using baseline comparison"
  r.source = "flux"
  r.source_type = "metric"
  r.source_name = "http.requests.count"
  r.rule_type = "anomaly"
  r.sensitivity = 7.0
  r.baseline_window = "7d"
  r.window = "15m"
  r.severity = "warning"
  r.enabled = true
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "api", type: "anomaly" }
end

# Response Time Anomaly
AlertRule.find_or_create_by!(project_id: project.id, slug: "response-time-anomaly") do |r|
  r.name = "Response Time Anomaly"
  r.description = "Detect unusual response time patterns"
  r.source = "pulse"
  r.source_type = "metric"
  r.source_name = "http.response_time"
  r.rule_type = "anomaly"
  r.sensitivity = 8.0
  r.baseline_window = "24h"
  r.window = "5m"
  r.severity = "warning"
  r.enabled = true
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "api", type: "anomaly" }
end

# ============================================================================
# Alert Rules - Absence Detection
# ============================================================================

# Missing Heartbeat
AlertRule.find_or_create_by!(project_id: project.id, slug: "missing-heartbeat") do |r|
  r.name = "Missing Heartbeat"
  r.description = "Alert when no heartbeat received in 5 minutes"
  r.source = "flux"
  r.source_type = "metric"
  r.source_name = "app.heartbeat"
  r.rule_type = "absence"
  r.expected_interval = "5m"
  r.severity = "critical"
  r.enabled = true
  r.notify_channels = [slack_channel.id, email_channel.id]
  r.labels = { service: "application", priority: "p1" }
end

# Missing Metrics
AlertRule.find_or_create_by!(project_id: project.id, slug: "missing-metrics") do |r|
  r.name = "Missing Metrics"
  r.description = "Alert when no metrics received in 10 minutes"
  r.source = "flux"
  r.source_type = "metric"
  r.source_name = "system.cpu.usage"
  r.rule_type = "absence"
  r.expected_interval = "10m"
  r.severity = "warning"
  r.enabled = true
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "infrastructure" }
end

# ============================================================================
# Muted Alert Rule Example
# ============================================================================

# Scheduled Maintenance Rule (muted)
muted_rule = AlertRule.find_or_create_by!(project_id: project.id, slug: "scheduled-job-failure") do |r|
  r.name = "Scheduled Job Failure"
  r.description = "Alert when scheduled jobs fail"
  r.source = "reflex"
  r.source_type = "event"
  r.source_name = "job.failed"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 0.0
  r.aggregation = "count"
  r.window = "15m"
  r.severity = "warning"
  r.enabled = true
  r.muted = true
  r.muted_until = 24.hours.from_now
  r.muted_reason = "Scheduled maintenance window"
  r.notify_channels = [slack_channel.id]
  r.labels = { service: "jobs" }
end

# Disabled Rule Example
AlertRule.find_or_create_by!(project_id: project.id, slug: "deprecated-metric-alert") do |r|
  r.name = "Deprecated Metric Alert"
  r.description = "Old alert rule - disabled"
  r.source = "flux"
  r.source_type = "metric"
  r.source_name = "legacy.metric"
  r.rule_type = "threshold"
  r.operator = "gt"
  r.threshold = 100.0
  r.aggregation = "avg"
  r.window = "5m"
  r.severity = "info"
  r.enabled = false
  r.notify_channels = []
  r.labels = { deprecated: true }
end

puts "  Created #{AlertRule.for_project(project.id).count} alert rules"
puts "    - Enabled: #{AlertRule.for_project(project.id).enabled.count}"
puts "    - Muted: #{AlertRule.for_project(project.id).where(muted: true).count}"

# ============================================================================
# Sample Alerts
# ============================================================================

puts "\nCreating sample alerts..."

# Find some rules to create alerts for
high_cpu_rule = AlertRule.find_by(project_id: project.id, slug: "high-cpu-usage")
high_error_rule = AlertRule.find_by(project_id: project.id, slug: "high-error-rate")
slow_response_rule = AlertRule.find_by(project_id: project.id, slug: "slow-response-time")
critical_cpu_rule = AlertRule.find_by(project_id: project.id, slug: "critical-cpu-usage")
security_rule = AlertRule.find_by(project_id: project.id, slug: "security-alert-pattern")

# Firing alert - High CPU
if high_cpu_rule
  Alert.find_or_create_by!(
    alert_rule: high_cpu_rule,
    fingerprint: "cpu-usage-web-1-prod"
  ) do |a|
    a.project_id = project.id
    a.state = "firing"
    a.labels = { host: "web-1", environment: "production" }
    a.current_value = 87.5
    a.threshold_value = 80.0
    a.started_at = 45.minutes.ago
    a.last_fired_at = 45.minutes.ago
    a.notification_count = 3
    a.last_notified_at = 15.minutes.ago
  end
end

# Firing alert - High Error Rate
if high_error_rule
  Alert.find_or_create_by!(
    alert_rule: high_error_rule,
    fingerprint: "error-rate-api-prod"
  ) do |a|
    a.project_id = project.id
    a.state = "firing"
    a.labels = { service: "api", environment: "production" }
    a.current_value = 8.2
    a.threshold_value = 5.0
    a.started_at = 20.minutes.ago
    a.last_fired_at = 20.minutes.ago
    a.notification_count = 2
    a.last_notified_at = 10.minutes.ago
  end
end

# Pending alert - Slow Response
if slow_response_rule
  Alert.find_or_create_by!(
    alert_rule: slow_response_rule,
    fingerprint: "response-time-checkout-prod"
  ) do |a|
    a.project_id = project.id
    a.state = "pending"
    a.labels = { endpoint: "/api/checkout", environment: "production" }
    a.current_value = 520.0
    a.threshold_value = 500.0
    a.started_at = 2.minutes.ago
    a.notification_count = 0
  end
end

# Acknowledged firing alert
if critical_cpu_rule
  Alert.find_or_create_by!(
    alert_rule: critical_cpu_rule,
    fingerprint: "critical-cpu-db-1-prod"
  ) do |a|
    a.project_id = project.id
    a.state = "firing"
    a.labels = { host: "db-1", environment: "production" }
    a.current_value = 97.3
    a.threshold_value = 95.0
    a.started_at = 2.hours.ago
    a.last_fired_at = 2.hours.ago
    a.notification_count = 5
    a.last_notified_at = 30.minutes.ago
    a.acknowledged = true
    a.acknowledged_at = 1.hour.ago
    a.acknowledged_by = "admin@example.com"
    a.acknowledgment_note = "Investigating - may be caused by backup job"
  end
end

# Resolved alert - Security
if security_rule
  Alert.find_or_create_by!(
    alert_rule: security_rule,
    fingerprint: "security-failed-auth-prod"
  ) do |a|
    a.project_id = project.id
    a.state = "resolved"
    a.labels = { source_ip: "192.168.1.100", environment: "production" }
    a.current_value = 15.0
    a.threshold_value = 10.0
    a.started_at = 6.hours.ago
    a.last_fired_at = 6.hours.ago
    a.resolved_at = 4.hours.ago
    a.notification_count = 2
    a.last_notified_at = 4.hours.ago
    a.acknowledged = true
    a.acknowledged_at = 5.hours.ago
    a.acknowledged_by = "security@example.com"
    a.acknowledgment_note = "Blocked IP at firewall level"
  end
end

# More resolved alerts for history
if high_cpu_rule
  Alert.find_or_create_by!(
    alert_rule: high_cpu_rule,
    fingerprint: "cpu-usage-web-2-prod-resolved"
  ) do |a|
    a.project_id = project.id
    a.state = "resolved"
    a.labels = { host: "web-2", environment: "production" }
    a.current_value = 82.0
    a.threshold_value = 80.0
    a.started_at = 1.day.ago
    a.last_fired_at = 1.day.ago
    a.resolved_at = 23.hours.ago
    a.notification_count = 1
    a.last_notified_at = 23.hours.ago
  end
end

if high_error_rule
  Alert.find_or_create_by!(
    alert_rule: high_error_rule,
    fingerprint: "error-rate-worker-prod-resolved"
  ) do |a|
    a.project_id = project.id
    a.state = "resolved"
    a.labels = { service: "worker", environment: "production" }
    a.current_value = 7.5
    a.threshold_value = 5.0
    a.started_at = 2.days.ago
    a.last_fired_at = 2.days.ago
    a.resolved_at = 2.days.ago + 30.minutes
    a.notification_count = 1
    a.last_notified_at = 2.days.ago + 30.minutes
  end
end

puts "  Created #{Alert.for_project(project.id).count} alerts"
puts "    - Firing: #{Alert.for_project(project.id).firing.count}"
puts "    - Pending: #{Alert.for_project(project.id).pending.count}"
puts "    - Resolved: #{Alert.for_project(project.id).resolved.count}"

# ============================================================================
# Escalation Policies
# ============================================================================

puts "\nCreating escalation policies..."

# Primary escalation policy with multiple steps
primary_escalation = EscalationPolicy.find_or_create_by!(
  project_id: project.id,
  slug: "primary-escalation"
) do |p|
  p.name = "Primary Escalation"
  p.description = "Default escalation policy for critical alerts"
  p.enabled = true
  p.repeat = true
  p.repeat_after_minutes = 30
  p.max_repeats = 3
  p.steps = [
    {
      delay_minutes: 0,
      targets: [
        { type: "channel", id: slack_channel.id, name: "Slack Alerts" }
      ]
    },
    {
      delay_minutes: 5,
      targets: [
        { type: "channel", id: email_channel.id, name: "Email On-Call" },
        { type: "schedule", slug: "primary-oncall" }
      ]
    },
    {
      delay_minutes: 15,
      targets: [
        { type: "channel", id: pagerduty_channel.id, name: "PagerDuty Critical" },
        { type: "user", email: "manager@example.com" }
      ]
    }
  ]
end

# Secondary escalation for non-critical
secondary_escalation = EscalationPolicy.find_or_create_by!(
  project_id: project.id,
  slug: "secondary-escalation"
) do |p|
  p.name = "Secondary Escalation"
  p.description = "Escalation policy for warning-level alerts"
  p.enabled = true
  p.repeat = false
  p.steps = [
    {
      delay_minutes: 0,
      targets: [
        { type: "channel", id: slack_channel.id, name: "Slack Alerts" }
      ]
    },
    {
      delay_minutes: 30,
      targets: [
        { type: "channel", id: email_channel.id, name: "Email On-Call" }
      ]
    }
  ]
end

# After-hours escalation
afterhours_escalation = EscalationPolicy.find_or_create_by!(
  project_id: project.id,
  slug: "afterhours-escalation"
) do |p|
  p.name = "After-Hours Escalation"
  p.description = "Aggressive escalation for off-hours critical issues"
  p.enabled = true
  p.repeat = true
  p.repeat_after_minutes = 15
  p.max_repeats = 5
  p.steps = [
    {
      delay_minutes: 0,
      targets: [
        { type: "channel", id: pagerduty_channel.id, name: "PagerDuty Critical" },
        { type: "schedule", slug: "afterhours-oncall" }
      ]
    },
    {
      delay_minutes: 5,
      targets: [
        { type: "user", email: "cto@example.com" },
        { type: "user", email: "sre-lead@example.com" }
      ]
    }
  ]
end

puts "  Created #{EscalationPolicy.for_project(project.id).count} escalation policies"

# Link some alert rules to escalation policies
AlertRule.find_by(project_id: project.id, slug: "critical-cpu-usage")&.update!(escalation_policy: primary_escalation)
AlertRule.find_by(project_id: project.id, slug: "critical-response-time")&.update!(escalation_policy: primary_escalation)
AlertRule.find_by(project_id: project.id, slug: "critical-error-spike")&.update!(escalation_policy: primary_escalation)
AlertRule.find_by(project_id: project.id, slug: "missing-heartbeat")&.update!(escalation_policy: afterhours_escalation)
AlertRule.find_by(project_id: project.id, slug: "security-alert-pattern")&.update!(escalation_policy: afterhours_escalation)
AlertRule.find_by(project_id: project.id, slug: "high-cpu-usage")&.update!(escalation_policy: secondary_escalation)
AlertRule.find_by(project_id: project.id, slug: "high-error-rate")&.update!(escalation_policy: secondary_escalation)

# ============================================================================
# On-Call Schedules
# ============================================================================

puts "\nCreating on-call schedules..."

# Primary on-call rotation (weekly)
OnCallSchedule.find_or_create_by!(
  project_id: project.id,
  slug: "primary-oncall"
) do |s|
  s.name = "Primary On-Call"
  s.schedule_type = "weekly"
  s.timezone = "America/Los_Angeles"
  s.enabled = true
  s.members = [
    { email: "alice@example.com", name: "Alice Chen", phone: "+1-555-0101" },
    { email: "bob@example.com", name: "Bob Smith", phone: "+1-555-0102" },
    { email: "carol@example.com", name: "Carol Johnson", phone: "+1-555-0103" },
    { email: "david@example.com", name: "David Lee", phone: "+1-555-0104" }
  ]
  s.weekly_schedule = {
    monday: { start: "09:00", end: "18:00", member: "alice@example.com" },
    tuesday: { start: "09:00", end: "18:00", member: "alice@example.com" },
    wednesday: { start: "09:00", end: "18:00", member: "bob@example.com" },
    thursday: { start: "09:00", end: "18:00", member: "bob@example.com" },
    friday: { start: "09:00", end: "18:00", member: "carol@example.com" }
  }
  s.current_on_call = "alice@example.com"
  s.current_shift_start = Time.current.beginning_of_day + 9.hours
  s.current_shift_end = Time.current.beginning_of_day + 18.hours
end

# After-hours on-call (rotation-based)
OnCallSchedule.find_or_create_by!(
  project_id: project.id,
  slug: "afterhours-oncall"
) do |s|
  s.name = "After-Hours On-Call"
  s.schedule_type = "custom"
  s.rotation_type = "weekly"
  s.timezone = "America/Los_Angeles"
  s.enabled = true
  s.rotation_start = Time.current.beginning_of_week
  s.members = [
    { email: "alice@example.com", name: "Alice Chen", phone: "+1-555-0101" },
    { email: "bob@example.com", name: "Bob Smith", phone: "+1-555-0102" },
    { email: "carol@example.com", name: "Carol Johnson", phone: "+1-555-0103" },
    { email: "david@example.com", name: "David Lee", phone: "+1-555-0104" }
  ]
  s.current_on_call = "david@example.com"
  s.current_shift_start = Time.current.beginning_of_week
  s.current_shift_end = Time.current.end_of_week
end

# Weekend on-call
OnCallSchedule.find_or_create_by!(
  project_id: project.id,
  slug: "weekend-oncall"
) do |s|
  s.name = "Weekend On-Call"
  s.schedule_type = "weekly"
  s.timezone = "America/Los_Angeles"
  s.enabled = true
  s.members = [
    { email: "david@example.com", name: "David Lee", phone: "+1-555-0104" },
    { email: "eve@example.com", name: "Eve Martinez", phone: "+1-555-0105" }
  ]
  s.weekly_schedule = {
    saturday: { start: "00:00", end: "23:59", member: "david@example.com" },
    sunday: { start: "00:00", end: "23:59", member: "eve@example.com" }
  }
  s.current_on_call = "david@example.com"
end

puts "  Created #{OnCallSchedule.for_project(project.id).count} on-call schedules"

# ============================================================================
# Maintenance Windows
# ============================================================================

puts "\nCreating maintenance windows..."

# Active maintenance window
MaintenanceWindow.find_or_create_by!(
  project_id: project.id,
  name: "Nightly Backup Window"
) do |m|
  m.description = "Suppress alerts during nightly database backup"
  m.starts_at = Time.current.beginning_of_day + 2.hours
  m.ends_at = Time.current.beginning_of_day + 4.hours
  m.active = true
  m.recurring = true
  m.recurrence_rule = "daily"
  m.created_by = "admin@example.com"
  m.services = ["database", "backup"]
  m.rule_ids = []  # All rules
end

# Upcoming maintenance window
MaintenanceWindow.find_or_create_by!(
  project_id: project.id,
  name: "Scheduled Deployment"
) do |m|
  m.description = "Planned deployment window for version 2.5.0"
  m.starts_at = 2.days.from_now.beginning_of_day + 14.hours
  m.ends_at = 2.days.from_now.beginning_of_day + 16.hours
  m.active = true
  m.recurring = false
  m.created_by = "devops@example.com"
  m.services = ["api", "web", "workers"]
  m.rule_ids = AlertRule.where(project_id: project.id, slug: %w[
    high-cpu-usage high-memory-usage slow-response-time
  ]).pluck(:id)
end

# Past maintenance window
MaintenanceWindow.find_or_create_by!(
  project_id: project.id,
  name: "Database Migration"
) do |m|
  m.description = "Completed database schema migration"
  m.starts_at = 3.days.ago
  m.ends_at = 3.days.ago + 2.hours
  m.active = false
  m.recurring = false
  m.created_by = "dba@example.com"
  m.services = ["database"]
end

# Weekly maintenance window
MaintenanceWindow.find_or_create_by!(
  project_id: project.id,
  name: "Weekly System Updates"
) do |m|
  m.description = "Regular system maintenance on Sundays"
  m.starts_at = Time.current.next_occurring(:sunday) + 6.hours
  m.ends_at = Time.current.next_occurring(:sunday) + 8.hours
  m.active = true
  m.recurring = true
  m.recurrence_rule = "weekly"
  m.created_by = "ops@example.com"
  m.services = ["infrastructure"]
end

puts "  Created #{MaintenanceWindow.for_project(project.id).count} maintenance windows"

# ============================================================================
# Incidents
# ============================================================================

puts "\nCreating incidents..."

# Active critical incident
cpu_incident = Incident.find_or_create_by!(
  project_id: project.id,
  title: "Database Server Performance Degradation"
) do |i|
  i.summary = "Multiple database servers experiencing high CPU usage, affecting query performance and response times across the platform."
  i.status = "acknowledged"
  i.severity = "critical"
  i.triggered_at = 2.hours.ago
  i.acknowledged_at = 1.hour.ago
  i.acknowledged_by = "sre@example.com"
  i.affected_services = ["database", "api", "web"]
  i.external_id = "INC-2024-0125"
  i.external_url = "https://status.example.com/incidents/INC-2024-0125"
  i.timeline = [
    { timestamp: 2.hours.ago.iso8601, event: "triggered", message: "Incident triggered by Critical CPU Usage alert" },
    { timestamp: 105.minutes.ago.iso8601, event: "alert_added", message: "High Error Rate alert added to incident" },
    { timestamp: 1.hour.ago.iso8601, event: "acknowledged", message: "Acknowledged by sre@example.com: Investigating root cause" },
    { timestamp: 45.minutes.ago.iso8601, event: "note", message: "Identified runaway query in reporting service" },
    { timestamp: 30.minutes.ago.iso8601, event: "note", message: "Scaling up database connection pool" }
  ]
end

# Active warning incident
error_incident = Incident.find_or_create_by!(
  project_id: project.id,
  title: "Elevated Error Rate in Checkout Service"
) do |i|
  i.summary = "Checkout service showing elevated error rates, some customers may experience failed transactions."
  i.status = "triggered"
  i.severity = "warning"
  i.triggered_at = 20.minutes.ago
  i.affected_services = ["checkout", "payments"]
  i.external_id = "INC-2024-0126"
  i.timeline = [
    { timestamp: 20.minutes.ago.iso8601, event: "triggered", message: "Incident triggered by High Error Rate alert" },
    { timestamp: 15.minutes.ago.iso8601, event: "notification", message: "Slack notification sent to #alerts" },
    { timestamp: 10.minutes.ago.iso8601, event: "notification", message: "Email sent to oncall@example.com" }
  ]
end

# Resolved incident
resolved_incident = Incident.find_or_create_by!(
  project_id: project.id,
  title: "Security Alert: Failed Authentication Attempts"
) do |i|
  i.summary = "Detected multiple failed authentication attempts from suspicious IP addresses. Traffic blocked at firewall."
  i.status = "resolved"
  i.severity = "critical"
  i.triggered_at = 6.hours.ago
  i.acknowledged_at = 5.hours.ago
  i.acknowledged_by = "security@example.com"
  i.resolved_at = 4.hours.ago
  i.resolved_by = "security@example.com"
  i.resolution_note = "Blocked malicious IP range at firewall level. No user accounts were compromised. Implemented additional rate limiting."
  i.affected_services = ["authentication", "api"]
  i.external_id = "INC-2024-0124"
  i.timeline = [
    { timestamp: 6.hours.ago.iso8601, event: "triggered", message: "Incident triggered by Security Alert Pattern" },
    { timestamp: 5.5.hours.ago.iso8601, event: "notification", message: "PagerDuty alert sent" },
    { timestamp: 5.hours.ago.iso8601, event: "acknowledged", message: "Acknowledged by security@example.com" },
    { timestamp: 4.5.hours.ago.iso8601, event: "note", message: "IP range 192.168.1.0/24 identified as source" },
    { timestamp: 4.25.hours.ago.iso8601, event: "note", message: "Firewall rule implemented to block traffic" },
    { timestamp: 4.hours.ago.iso8601, event: "resolved", message: "Resolved: Malicious traffic blocked, no breach detected" }
  ]
end

# Another resolved incident (older)
old_incident = Incident.find_or_create_by!(
  project_id: project.id,
  title: "API Latency Spike During Peak Hours"
) do |i|
  i.summary = "API response times spiked during peak traffic period. Auto-scaling resolved the issue."
  i.status = "resolved"
  i.severity = "warning"
  i.triggered_at = 1.day.ago
  i.acknowledged_at = 1.day.ago + 5.minutes
  i.acknowledged_by = "oncall@example.com"
  i.resolved_at = 1.day.ago + 45.minutes
  i.resolved_by = "system"
  i.resolution_note = "Auto-scaling kicked in after 15 minutes. Added 3 additional API pods."
  i.affected_services = ["api"]
  i.external_id = "INC-2024-0123"
  i.timeline = [
    { timestamp: 1.day.ago.iso8601, event: "triggered", message: "Slow Response Time alert triggered" },
    { timestamp: (1.day.ago + 5.minutes).iso8601, event: "acknowledged", message: "Acknowledged by oncall@example.com" },
    { timestamp: (1.day.ago + 15.minutes).iso8601, event: "note", message: "Auto-scaling triggered" },
    { timestamp: (1.day.ago + 45.minutes).iso8601, event: "resolved", message: "Response times normalized" }
  ]
end

puts "  Created #{Incident.for_project(project.id).count} incidents"
puts "    - Triggered: #{Incident.for_project(project.id).where(status: 'triggered').count}"
puts "    - Acknowledged: #{Incident.for_project(project.id).where(status: 'acknowledged').count}"
puts "    - Resolved: #{Incident.for_project(project.id).where(status: 'resolved').count}"

# Link alerts to incidents
Alert.find_by(fingerprint: "critical-cpu-db-1-prod")&.update!(incident: cpu_incident)
Alert.find_by(fingerprint: "error-rate-api-prod")&.update!(incident: error_incident)
Alert.find_by(fingerprint: "security-failed-auth-prod")&.update!(incident: resolved_incident)

# ============================================================================
# Notifications
# ============================================================================

puts "\nCreating notifications..."

# Get some alerts for notifications
firing_alerts = Alert.for_project(project.id).firing

firing_alerts.each do |alert|
  # Sent notification
  Notification.find_or_create_by!(
    project_id: project.id,
    alert: alert,
    notification_channel: slack_channel,
    notification_type: "alert_fired"
  ) do |n|
    n.status = "sent"
    n.sent_at = alert.last_notified_at || 15.minutes.ago
    n.payload = {
      alert_id: alert.id,
      rule_name: alert.alert_rule.name,
      severity: alert.alert_rule.severity,
      current_value: alert.current_value,
      threshold_value: alert.threshold_value,
      labels: alert.labels
    }
    n.response = { ok: true, ts: "1234567890.123456" }
  end
end

# Email notification for critical alert
critical_alert = Alert.joins(:alert_rule)
                      .where(alert_rules: { project_id: project.id, severity: "critical" })
                      .firing.first
if critical_alert
  Notification.find_or_create_by!(
    project_id: project.id,
    alert: critical_alert,
    notification_channel: email_channel,
    notification_type: "alert_fired"
  ) do |n|
    n.status = "sent"
    n.sent_at = 30.minutes.ago
    n.payload = {
      subject: "[CRITICAL] #{critical_alert.alert_rule.name}",
      recipients: ["oncall@example.com"],
      body: "Alert triggered: #{critical_alert.alert_rule.description}"
    }
    n.response = { message_id: "abc123@example.com" }
  end
end

# Failed notification
Notification.find_or_create_by!(
  project_id: project.id,
  notification_channel: webhook_channel,
  notification_type: "alert_fired"
) do |n|
  n.alert = firing_alerts.first
  n.status = "failed"
  n.retry_count = 3
  n.error_message = "Connection timeout: Failed to connect to api.example.com:443"
  n.next_retry_at = nil  # Exhausted retries
  n.payload = {
    event: "alert_fired",
    alert_id: firing_alerts.first&.id
  }
end

# Pending notification
Notification.find_or_create_by!(
  project_id: project.id,
  notification_channel: pagerduty_channel,
  notification_type: "incident_triggered"
) do |n|
  n.incident = cpu_incident
  n.status = "pending"
  n.payload = {
    routing_key: "EXAMPLE_KEY",
    event_action: "trigger",
    dedup_key: "incident-#{cpu_incident.id}",
    payload: {
      summary: cpu_incident.title,
      severity: cpu_incident.severity,
      source: "Signal"
    }
  }
end

# Incident notifications
Notification.find_or_create_by!(
  project_id: project.id,
  incident: resolved_incident,
  notification_channel: slack_channel,
  notification_type: "incident_resolved"
) do |n|
  n.status = "sent"
  n.sent_at = 4.hours.ago
  n.payload = {
    incident_id: resolved_incident.id,
    title: resolved_incident.title,
    resolution: resolved_incident.resolution_note
  }
  n.response = { ok: true }
end

puts "  Created #{Notification.for_project(project.id).count} notifications"
puts "    - Sent: #{Notification.for_project(project.id).where(status: 'sent').count}"
puts "    - Pending: #{Notification.for_project(project.id).where(status: 'pending').count}"
puts "    - Failed: #{Notification.for_project(project.id).where(status: 'failed').count}"

# ============================================================================
# Alert Histories
# ============================================================================

puts "\nCreating alert histories..."

# Generate history for high CPU rule
high_cpu_rule = AlertRule.find_by(project_id: project.id, slug: "high-cpu-usage")
if high_cpu_rule
  # Simulated history over last 24 hours
  24.times do |i|
    timestamp = (24 - i).hours.ago
    value = 50 + rand(40) + (i > 18 ? 30 : 0)  # Spike in recent hours
    state = value > 80 ? "firing" : "ok"

    AlertHistory.find_or_create_by!(
      alert_rule_id: high_cpu_rule.id,
      project_id: project.id,
      timestamp: timestamp,
      fingerprint: "cpu-history-#{timestamp.to_i}"
    ) do |h|
      h.state = state
      h.value = value.round(1)
      h.labels = { host: "web-1", environment: "production" }
    end
  end
end

# Generate history for error rate rule
high_error_rule = AlertRule.find_by(project_id: project.id, slug: "high-error-rate")
if high_error_rule
  24.times do |i|
    timestamp = (24 - i).hours.ago
    value = 1 + rand(3) + (i > 20 ? 5 : 0)  # Recent spike
    state = value > 5 ? "firing" : "ok"

    AlertHistory.find_or_create_by!(
      alert_rule_id: high_error_rule.id,
      project_id: project.id,
      timestamp: timestamp,
      fingerprint: "error-history-#{timestamp.to_i}"
    ) do |h|
      h.state = state
      h.value = value.round(2)
      h.labels = { service: "api", environment: "production" }
    end
  end
end

# Generate history for response time rule
slow_response_rule = AlertRule.find_by(project_id: project.id, slug: "slow-response-time")
if slow_response_rule
  24.times do |i|
    timestamp = (24 - i).hours.ago
    value = 200 + rand(200) + (i > 22 ? 200 : 0)  # Recent increase
    state = value > 500 ? "firing" : "ok"

    AlertHistory.find_or_create_by!(
      alert_rule_id: slow_response_rule.id,
      project_id: project.id,
      timestamp: timestamp,
      fingerprint: "response-history-#{timestamp.to_i}"
    ) do |h|
      h.state = state
      h.value = value.round(0)
      h.labels = { endpoint: "/api/checkout", environment: "production" }
    end
  end
end

puts "  Created #{AlertHistory.for_project(project.id).count} alert history entries"

# ============================================================================
# Additional Discord and Teams Channels
# ============================================================================

puts "\nCreating additional notification channels..."

NotificationChannel.find_or_create_by!(
  project_id: project.id,
  slug: "discord-devops"
) do |c|
  c.name = "Discord DevOps"
  c.channel_type = "discord"
  c.enabled = true
  c.verified = true
  c.config = {
    webhook_url: "https://discord.com/api/webhooks/EXAMPLE/TOKEN",
    username: "Signal Bot",
    avatar_url: "https://brainzlab.ai/signal-avatar.png"
  }
end

NotificationChannel.find_or_create_by!(
  project_id: project.id,
  slug: "teams-engineering"
) do |c|
  c.name = "Teams Engineering"
  c.channel_type = "teams"
  c.enabled = false
  c.verified = false
  c.config = {
    webhook_url: "https://outlook.office.com/webhook/EXAMPLE"
  }
end

NotificationChannel.find_or_create_by!(
  project_id: project.id,
  slug: "opsgenie-critical"
) do |c|
  c.name = "Opsgenie Critical"
  c.channel_type = "opsgenie"
  c.enabled = true
  c.verified = true
  c.config = {
    api_key: "EXAMPLE_API_KEY",
    team: "platform-sre",
    priority: "P1"
  }
end

puts "  Total notification channels: #{NotificationChannel.for_project(project.id).count}"

# ============================================================================
# Summary
# ============================================================================

puts "\n" + "=" * 60
puts "Seeding complete!"
puts "=" * 60
puts "  Projects: #{Project.count}"
puts "  Notification channels: #{NotificationChannel.for_project(project.id).count}"
puts "  Alert rules: #{AlertRule.for_project(project.id).count}"
puts "    - Threshold: #{AlertRule.for_project(project.id).where(rule_type: 'threshold').count}"
puts "    - Anomaly: #{AlertRule.for_project(project.id).where(rule_type: 'anomaly').count}"
puts "    - Absence: #{AlertRule.for_project(project.id).where(rule_type: 'absence').count}"
puts "  Alerts: #{Alert.for_project(project.id).count}"
puts "    - Active: #{Alert.for_project(project.id).active.count}"
puts "    - Resolved: #{Alert.for_project(project.id).resolved.count}"
puts "  Incidents: #{Incident.for_project(project.id).count}"
puts "    - Active: #{Incident.for_project(project.id).where.not(status: 'resolved').count}"
puts "    - Resolved: #{Incident.for_project(project.id).where(status: 'resolved').count}"
puts "  Escalation policies: #{EscalationPolicy.for_project(project.id).count}"
puts "  On-call schedules: #{OnCallSchedule.for_project(project.id).count}"
puts "  Maintenance windows: #{MaintenanceWindow.for_project(project.id).count}"
puts "  Notifications: #{Notification.for_project(project.id).count}"
puts "  Alert histories: #{AlertHistory.for_project(project.id).count}"
puts "=" * 60
