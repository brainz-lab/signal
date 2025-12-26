# Signal Test Suite

This directory contains comprehensive RSpec tests for the Signal alerting system.

## Setup

1. Install test dependencies:
```bash
bundle install
```

2. Set up the test database:
```bash
RAILS_ENV=test bundle exec rails db:create db:schema:load
```

3. Run the tests:
```bash
bundle exec rspec
```

## Test Structure

### Models (`spec/models/`)
- **alert_spec.rb** - Alert model validations, associations, state transitions, and notification logic
- **alert_rule_spec.rb** - Alert rule validations, scopes, evaluation, muting, and condition descriptions
- **incident_spec.rb** - Incident lifecycle, acknowledgment, resolution, and timeline management
- **notification_channel_spec.rb** - Channel types, notifier delegation, and testing
- **notification_spec.rb** - Notification statuses and scopes
- **maintenance_window_spec.rb** - Maintenance window validations and coverage logic
- **on_call_schedule_spec.rb** - On-call rotation logic for weekly and custom schedules
- **escalation_policy_spec.rb** - Escalation policy validations and associations

### Controllers (`spec/controllers/api/v1/`)
- **alerts_controller_spec.rb** - API endpoints for listing, showing, acknowledging, triggering, and resolving alerts

### Jobs (`spec/jobs/`)
- **notification_job_spec.rb** - Notification delivery with maintenance window checks
- **rule_evaluation_job_spec.rb** - Alert rule evaluation for single and batch processing

### Services (`spec/services/`)
- **alert_manager_spec.rb** - Alert state management (pending, firing, resolved)
- **incident_manager_spec.rb** - Incident creation and auto-resolution

### Factories (`spec/factories/`)
FactoryBot factories for all models with traits for common scenarios:
- Alerts (firing, resolved, acknowledged)
- Alert rules (critical, muted, disabled, different types)
- Incidents (acknowledged, resolved, critical)
- Notification channels (all types, verified, disabled)
- Maintenance windows (current, past, future)
- On-call schedules (weekly, custom rotation)

## Running Tests

Run all tests:
```bash
bundle exec rspec
```

Run specific test file:
```bash
bundle exec rspec spec/models/alert_spec.rb
```

Run specific test:
```bash
bundle exec rspec spec/models/alert_spec.rb:10
```

Run with documentation format:
```bash
bundle exec rspec --format documentation
```

## Coverage

The test suite covers:
- ✅ Model validations and associations
- ✅ Scopes and query methods
- ✅ Business logic methods
- ✅ State transitions
- ✅ API endpoints
- ✅ Background jobs
- ✅ Service objects
- ✅ Edge cases and error handling

## Key Testing Patterns

### Time-dependent tests
```ruby
freeze_time do
  # Your test code
end
```

### Sidekiq jobs
Jobs run in fake mode by default. Check if jobs are enqueued:
```ruby
expect(NotificationJob).to have_been_enqueued
```

### API authentication
Use the `api_headers` helper:
```ruby
request.headers.merge!(api_headers(project_id))
```

### Factory usage
```ruby
# Basic factory
create(:alert)

# With traits
create(:alert, :firing, :acknowledged)

# Build without saving
build(:alert)
```
