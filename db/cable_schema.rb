# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_20_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "timescaledb"
  enable_extension "uuid-ossp"
  enable_extension "vector"

  create_table "alert_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "alert_rule_id", null: false
    t.string "fingerprint"
    t.jsonb "labels", default: {}
    t.uuid "project_id", null: false
    t.string "state", null: false
    t.datetime "timestamp", null: false
    t.float "value"
    t.index ["alert_rule_id", "timestamp"], name: "index_alert_histories_on_alert_rule_id_and_timestamp"
    t.index ["alert_rule_id"], name: "index_alert_histories_on_alert_rule_id"
    t.index ["project_id", "timestamp"], name: "index_alert_histories_on_project_id_and_timestamp"
    t.index ["project_id"], name: "index_alert_histories_on_project_id"
  end

  create_table "alert_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "aggregation"
    t.jsonb "annotations", default: {}
    t.string "baseline_window"
    t.string "composite_operator"
    t.jsonb "composite_rules", default: []
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true
    t.uuid "escalation_policy_id"
    t.integer "evaluation_interval", default: 60
    t.string "expected_interval"
    t.jsonb "group_by", default: []
    t.jsonb "labels", default: {}
    t.datetime "last_evaluated_at"
    t.string "last_state"
    t.boolean "muted", default: false
    t.string "muted_reason"
    t.datetime "muted_until"
    t.string "name", null: false
    t.jsonb "notify_channels", default: []
    t.string "operator"
    t.integer "pending_period", default: 0
    t.uuid "project_id", null: false
    t.jsonb "query", default: {}
    t.integer "resolve_period", default: 300
    t.string "rule_type", null: false
    t.float "sensitivity"
    t.string "severity", default: "warning"
    t.string "slug", null: false
    t.string "source", null: false
    t.string "source_name"
    t.string "source_type"
    t.float "threshold"
    t.datetime "updated_at", null: false
    t.string "window"
    t.index ["project_id", "severity"], name: "index_alert_rules_on_project_id_and_severity"
    t.index ["project_id", "slug"], name: "index_alert_rules_on_project_id_and_slug", unique: true
    t.index ["project_id", "source", "enabled"], name: "index_alert_rules_on_project_id_and_source_and_enabled"
    t.index ["project_id"], name: "index_alert_rules_on_project_id"
  end

  create_table "alerts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "acknowledged", default: false
    t.datetime "acknowledged_at"
    t.string "acknowledged_by"
    t.text "acknowledgment_note"
    t.uuid "alert_rule_id", null: false
    t.datetime "created_at", null: false
    t.float "current_value"
    t.string "fingerprint", null: false
    t.uuid "incident_id"
    t.jsonb "labels", default: {}
    t.datetime "last_fired_at"
    t.datetime "last_notified_at"
    t.integer "notification_count", default: 0
    t.uuid "project_id", null: false
    t.datetime "resolved_at"
    t.datetime "started_at", null: false
    t.string "state", null: false
    t.float "threshold_value"
    t.datetime "updated_at", null: false
    t.index ["alert_rule_id", "fingerprint"], name: "index_alerts_on_alert_rule_id_and_fingerprint", unique: true, where: "((state)::text <> 'resolved'::text)"
    t.index ["alert_rule_id"], name: "index_alerts_on_alert_rule_id"
    t.index ["fingerprint"], name: "index_alerts_on_fingerprint"
    t.index ["project_id", "started_at"], name: "index_alerts_on_project_id_and_started_at"
    t.index ["project_id", "state"], name: "index_alerts_on_project_id_and_state"
    t.index ["project_id"], name: "index_alerts_on_project_id"
  end

  create_table "escalation_policies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true
    t.integer "max_repeats"
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.boolean "repeat", default: false
    t.integer "repeat_after_minutes"
    t.string "slug", null: false
    t.jsonb "steps", default: []
    t.datetime "updated_at", null: false
    t.index ["project_id", "slug"], name: "index_escalation_policies_on_project_id_and_slug", unique: true
    t.index ["project_id"], name: "index_escalation_policies_on_project_id"
  end

  create_table "incidents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.string "acknowledged_by"
    t.jsonb "affected_services", default: []
    t.datetime "created_at", null: false
    t.string "external_id"
    t.string "external_url"
    t.uuid "project_id", null: false
    t.text "resolution_note"
    t.datetime "resolved_at"
    t.string "resolved_by"
    t.string "severity", null: false
    t.string "status", null: false
    t.text "summary"
    t.jsonb "timeline", default: []
    t.string "title", null: false
    t.datetime "triggered_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "severity"], name: "index_incidents_on_project_id_and_severity"
    t.index ["project_id", "status"], name: "index_incidents_on_project_id_and_status"
    t.index ["project_id", "triggered_at"], name: "index_incidents_on_project_id_and_triggered_at"
    t.index ["project_id"], name: "index_incidents_on_project_id"
  end

  create_table "maintenance_windows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "created_by"
    t.text "description"
    t.datetime "ends_at", null: false
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.string "recurrence_rule"
    t.boolean "recurring", default: false
    t.jsonb "rule_ids", default: []
    t.jsonb "services", default: []
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "active"], name: "index_maintenance_windows_on_project_id_and_active"
    t.index ["project_id", "starts_at", "ends_at"], name: "idx_on_project_id_starts_at_ends_at_5580d5ef95"
    t.index ["project_id"], name: "index_maintenance_windows_on_project_id"
  end

  create_table "notification_channels", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "channel_type", null: false
    t.jsonb "config", default: {}
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true
    t.integer "failure_count", default: 0
    t.string "last_test_status"
    t.datetime "last_tested_at"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.string "slug", null: false
    t.integer "success_count", default: 0
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false
    t.index ["project_id", "channel_type"], name: "index_notification_channels_on_project_id_and_channel_type"
    t.index ["project_id", "slug"], name: "index_notification_channels_on_project_id_and_slug", unique: true
    t.index ["project_id"], name: "index_notification_channels_on_project_id"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "alert_id"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.uuid "incident_id"
    t.datetime "next_retry_at"
    t.uuid "notification_channel_id", null: false
    t.string "notification_type", null: false
    t.jsonb "payload", default: {}
    t.uuid "project_id", null: false
    t.jsonb "response", default: {}
    t.integer "retry_count", default: 0
    t.datetime "sent_at"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["alert_id"], name: "index_notifications_on_alert_id"
    t.index ["incident_id"], name: "index_notifications_on_incident_id"
    t.index ["notification_channel_id", "status"], name: "index_notifications_on_notification_channel_id_and_status"
    t.index ["notification_channel_id"], name: "index_notifications_on_notification_channel_id"
    t.index ["project_id", "created_at"], name: "index_notifications_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_notifications_on_project_id"
    t.index ["status", "next_retry_at"], name: "index_notifications_on_status_and_next_retry_at", where: "((status)::text = 'failed'::text)"
  end

  create_table "on_call_schedules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "current_on_call"
    t.datetime "current_shift_end"
    t.datetime "current_shift_start"
    t.boolean "enabled", default: true
    t.jsonb "members", default: []
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.datetime "rotation_start"
    t.string "rotation_type"
    t.string "schedule_type", null: false
    t.string "slug", null: false
    t.string "timezone", default: "UTC"
    t.datetime "updated_at", null: false
    t.jsonb "weekly_schedule", default: {}
    t.index ["project_id", "slug"], name: "index_on_call_schedules_on_project_id_and_slug", unique: true
    t.index ["project_id"], name: "index_on_call_schedules_on_project_id"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "environment", default: "live"
    t.string "name"
    t.uuid "platform_project_id", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_projects_on_archived_at"
    t.index ["platform_project_id"], name: "index_projects_on_platform_project_id", unique: true
  end

  create_table "saved_searches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "project_id", null: false
    t.jsonb "query_params", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_saved_searches_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_saved_searches_on_project_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  add_foreign_key "alert_histories", "alert_rules"
  add_foreign_key "alert_rules", "escalation_policies"
  add_foreign_key "alerts", "alert_rules"
  add_foreign_key "alerts", "incidents"
  add_foreign_key "notifications", "alerts"
  add_foreign_key "notifications", "incidents"
  add_foreign_key "notifications", "notification_channels"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
