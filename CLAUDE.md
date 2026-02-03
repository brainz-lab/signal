# CLAUDE.md

> **Secrets Reference**: See `../.secrets.md` (gitignored) for master keys, server access, and MCP tokens.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Signal by Brainz Lab

Unified alerting and notification system for all Brainz Lab products.

**Domain**: signal.brainzlab.ai

**Tagline**: "Know before your users do"

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         SIGNAL (Rails 8)                         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Dashboard   │  │     API      │  │  MCP Server  │           │
│  │  (Hotwire)   │  │  (JSON API)  │  │   (Ruby)     │           │
│  │ /dashboard/* │  │  /api/v1/*   │  │   /mcp/*     │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                           │                  │                   │
│                           ▼                  ▼                   │
│              ┌─────────────────────────────────────┐            │
│              │    PostgreSQL + Redis (Sidekiq)     │            │
│              └─────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
          ▲                                         │
          │ Query                                   │ Notify
┌─────────┴─────────┐                   ┌──────────┴──────────┐
│  DATA SOURCES     │                   │  CHANNELS           │
│  Flux, Pulse,     │                   │  Slack, PagerDuty,  │
│  Reflex, Recall   │                   │  Email, Webhook...  │
└───────────────────┘                   └─────────────────────┘
```

## Tech Stack

- **Backend**: Rails 8 API + Dashboard
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq (for scheduled evaluations)
- **Caching**: Redis
- **WebSockets**: Solid Cable (real-time alerts)
- **MCP Server**: Ruby (integrated into Rails)

## Common Commands

```bash
# Development
bin/rails server
bin/rails console
bin/rails db:migrate

# Testing
bin/rails test
bin/rails test test/models/alert_rule_test.rb

# Sidekiq (for rule evaluation)
bundle exec sidekiq

# Docker (from brainzlab root)
docker-compose --profile signal up
docker-compose exec signal bin/rails db:migrate

# Database
bin/rails db:create db:migrate
bin/rails db:seed
```

## Key Models

- **AlertRule**: Rule definition (threshold, anomaly, absence, composite)
- **Alert**: Triggered alert instance with state (firing, resolved)
- **Incident**: Grouped alerts for the same issue
- **NotificationChannel**: Configured notification destination (Slack, PagerDuty, etc.)
- **Notification**: Delivery record for an alert
- **EscalationPolicy**: Multi-step escalation configuration
- **OnCallSchedule**: Who's on call and when
- **MaintenanceWindow**: Suppress alerts during maintenance
- **AlertHistory**: Historical record of state changes

## Alert Rule Types

- **Threshold**: `metric > value` (gt, gte, lt, lte, eq, neq)
- **Anomaly**: AI-detected deviations from baseline
- **Absence**: No data received within expected interval
- **Composite**: Multiple rules combined (AND/OR)

## Data Sources

Signal queries data from other Brainz Lab products:
- **Flux**: Metrics and events
- **Pulse**: APM traces, response times, Apdex
- **Reflex**: Error rates, exception counts
- **Recall**: Log patterns, error logs

## Notification Channels

| Channel | Description |
|---------|-------------|
| Slack | Post to channels or DM |
| PagerDuty | Create incidents, trigger on-call |
| Email | Send to individuals or groups |
| Webhook | HTTP POST to custom endpoint |
| Discord | Post to Discord channels |
| Teams | Microsoft Teams messages |
| Opsgenie | Opsgenie incident integration |

## Key Services

- **RuleEvaluator**: Evaluates alert rules against data sources
- **AlertManager**: Creates/updates alerts, handles state transitions
- **IncidentManager**: Groups related alerts into incidents
- **Notifiers::***: Channel-specific notification delivery

## API Endpoints

**Alerts**:
- `GET /api/v1/alerts` - List alerts
- `GET /api/v1/alerts/:id` - Get alert details
- `POST /api/v1/alerts/:id/acknowledge` - Acknowledge alert
- `POST /api/v1/alerts/:id/resolve` - Resolve alert
- `POST /api/v1/alerts/:id/mute` - Mute alert

**Rules**:
- `GET /api/v1/rules` - List rules
- `POST /api/v1/rules` - Create rule
- `PUT /api/v1/rules/:id` - Update rule
- `DELETE /api/v1/rules/:id` - Delete rule
- `POST /api/v1/rules/:id/test` - Test rule

**Channels**:
- `GET /api/v1/channels` - List channels
- `POST /api/v1/channels` - Create channel
- `POST /api/v1/channels/:id/test` - Test channel

**Incidents**:
- `GET /api/v1/incidents` - List incidents
- `POST /api/v1/incidents/:id/acknowledge` - Acknowledge incident

**MCP**:
- `GET /mcp/tools` - List tools
- `POST /mcp/tools/:name` - Call tool

Authentication: `Authorization: Bearer <key>` or `X-API-Key: <key>`

## MCP Tools

| Tool | Description |
|------|-------------|
| `signal_list_alerts` | List active alerts |
| `signal_acknowledge` | Acknowledge an alert |
| `signal_create_rule` | Create a new alert rule |
| `signal_mute` | Mute alerts temporarily |
| `signal_incidents` | List incidents |

## Background Jobs

| Job | Schedule | Description |
|-----|----------|-------------|
| `RuleEvaluationJob` | Every 1 min | Evaluate all active rules |
| `NotificationJob` | On trigger | Deliver notifications |
| `EscalationJob` | On schedule | Handle escalation policies |
| `DigestJob` | Configurable | Send alert digests |

## Alert Severity Levels

- **info**: Informational, no action needed
- **warning**: Potential issue, investigate soon
- **critical**: Immediate action required

## Design Principles

- Clean, minimal UI like Anthropic/Claude
- Real-time alert updates via WebSocket
- Unified alerting across all data sources
- Intelligent grouping to reduce noise
- Flexible escalation policies
- Maintenance windows to prevent alert fatigue

## Kamal Production Access

**IMPORTANT**: When using `kamal app exec --reuse`, docker exec doesn't inherit container environment variables. You must pass `SECRET_KEY_BASE` explicitly.

```bash
# Navigate to this service directory
cd /Users/afmp/brainz/brainzlab/signal

# Get the master key (used as SECRET_KEY_BASE)
cat config/master.key

# Run Rails console commands
kamal app exec -p --reuse -e SECRET_KEY_BASE:<master_key> 'bin/rails runner "<ruby_code>"'

# Example: Count alerts
kamal app exec -p --reuse -e SECRET_KEY_BASE:<master_key> 'bin/rails runner "puts Alert.count"'
```

### Running Complex Scripts

For multi-line Ruby scripts, create a local file, scp to server, docker cp into container, then run with rails runner. See main brainzlab/CLAUDE.md for details.

### Other Kamal Commands

```bash
kamal deploy              # Deploy
kamal app logs -f         # View logs
kamal lock release        # Release stuck lock
kamal secrets print       # Print evaluated secrets
```
