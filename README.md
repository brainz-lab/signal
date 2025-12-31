# Signal - Unified Alerting & Notifications

[![CI](https://github.com/brainz-lab/signal/actions/workflows/ci.yml/badge.svg)](https://github.com/brainz-lab/signal/actions/workflows/ci.yml)
[![CodeQL](https://github.com/brainz-lab/signal/actions/workflows/codeql.yml/badge.svg)](https://github.com/brainz-lab/signal/actions/workflows/codeql.yml)
[![codecov](https://codecov.io/gh/brainz-lab/signal/graph/badge.svg)](https://codecov.io/gh/brainz-lab/signal)
[![License: OSAaSy](https://img.shields.io/badge/License-OSAaSy-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-3.2+-red.svg)](https://www.ruby-lang.org)

Signal is the unified alerting system for Brainz Lab. It monitors all your data sources (Flux, Pulse, Reflex, Recall), detects issues using configurable rules, and notifies your team through multiple channels.

## Features

- **Alert Rules**: Threshold, anomaly detection, absence detection, composite rules
- **Data Sources**: Integrates with Flux (metrics), Pulse (APM), Reflex (errors), Recall (logs)
- **Notification Channels**: Slack, PagerDuty, Email, Webhook, Discord, Microsoft Teams, Opsgenie
- **Incidents**: Automatic incident grouping with timeline tracking
- **Escalation Policies**: Multi-step escalation with configurable delays
- **On-call Schedules**: Weekly and rotation-based scheduling
- **Maintenance Windows**: Scheduled alert muting

## Quick Start

### With Docker Compose (Recommended)

From the brainzlab root directory:

```bash
docker-compose --profile signal up
```

Access at: http://localhost:4005

### Standalone Development

```bash
cd signal
bundle install
bin/rails db:create db:migrate
bin/rails server -p 4005
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/v1/alerts` | List alerts |
| `POST /api/v1/alerts/:id/acknowledge` | Acknowledge alert |
| `GET /api/v1/rules` | List alert rules |
| `POST /api/v1/rules` | Create rule |
| `POST /api/v1/rules/:id/mute` | Mute rule |
| `GET /api/v1/channels` | List notification channels |
| `POST /api/v1/channels/:id/test` | Test channel |
| `GET /api/v1/incidents` | List incidents |

## MCP Tools

| Tool | Description |
|------|-------------|
| `signal_list_alerts` | List active alerts |
| `signal_acknowledge` | Acknowledge an alert |
| `signal_create_rule` | Create alert rule |
| `signal_mute` | Mute a rule |
| `signal_incidents` | List incidents |

## Creating an Alert Rule

```ruby
# Via API
POST /api/v1/rules
{
  "rule": {
    "name": "High Error Rate",
    "source": "reflex",
    "source_name": "error_count",
    "rule_type": "threshold",
    "operator": "gt",
    "threshold": 100,
    "window": "5m",
    "severity": "critical",
    "notify_channels": ["<channel-uuid>"]
  }
}
```

## Setting Up Notification Channels

### Slack

```ruby
POST /api/v1/channels
{
  "channel": {
    "name": "ops-alerts",
    "channel_type": "slack",
    "config": {
      "webhook_url": "https://hooks.slack.com/...",
      "channel": "#ops"
    }
  }
}
```

### PagerDuty

```ruby
POST /api/v1/channels
{
  "channel": {
    "name": "pagerduty-critical",
    "channel_type": "pagerduty",
    "config": {
      "routing_key": "your-routing-key",
      "severity_map": {
        "critical": "critical",
        "warning": "warning"
      }
    }
  }
}
```

## Architecture

```
Signal
├── Alert Rules      # Define conditions for alerts
├── Alerts          # Active alert instances
├── Incidents       # Groups related alerts
├── Channels        # Notification destinations
├── Policies        # Escalation configurations
├── Schedules       # On-call rotations
└── Windows         # Maintenance periods
```

## Background Jobs

- `RuleEvaluationJob` - Evaluates all active rules (runs every minute)
- `NotificationJob` - Sends notifications to channels
- `EscalationJob` - Handles escalation steps
- `DigestJob` - Sends periodic alert digests
- `CleanupJob` - Removes old alerts and history

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection | - |
| `REDIS_URL` | Redis for Sidekiq | `redis://localhost:6379/0` |
| `FLUX_URL` | Flux service URL | `http://flux:3000` |
| `PULSE_URL` | Pulse service URL | `http://pulse:3000` |
| `REFLEX_URL` | Reflex service URL | `http://reflex:3000` |
| `RECALL_URL` | Recall service URL | `http://recall:3000` |
| `SIGNAL_URL` | Public URL for links | `https://signal.brainzlab.ai` |

## Contributors

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

Thanks to all our contributors! See [all-contributors](https://allcontributors.org) for how to add yourself.
