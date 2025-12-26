# Test Coverage Summary for Signal

## Overview
Comprehensive RSpec test suite created from scratch for the Signal alerting system.

## Test Statistics

### Models (9 test files)
1. **Alert** (`spec/models/alert_spec.rb`)
   - Associations: belongs_to alert_rule, belongs_to incident, has_many notifications
   - Validations: fingerprint, state, project_id
   - Scopes: active, firing, pending, resolved, unacknowledged, for_project, recent
   - Methods: fire!, resolve!, acknowledge!, duration, duration_human, severity
   - Private: notify! (with muting and maintenance window logic)

2. **AlertRule** (`spec/models/alert_rule_spec.rb`)
   - Associations: belongs_to escalation_policy, has_many alerts, has_many alert_histories
   - Validations: name, slug, source, rule_type, severity, project_id
   - Uniqueness: slug scoped to project_id
   - Callbacks: generate_slug before_validation
   - Scopes: enabled, active, by_source, firing, for_project
   - Methods: evaluate!, mute!, unmute!, muted?, notification_channels, condition_description
   - All rule types: threshold, anomaly, absence, composite

3. **Incident** (`spec/models/incident_spec.rb`)
   - Associations: has_many alerts, has_many notifications
   - Validations: title, status, severity, project_id
   - Scopes: open, resolved, by_severity, recent, for_project
   - Methods: acknowledge!, resolve!, add_timeline_event, duration
   - Timeline management and state transitions

4. **NotificationChannel** (`spec/models/notification_channel_spec.rb`)
   - Associations: has_many notifications
   - Validations: name, slug, channel_type, project_id
   - Channel types: slack, pagerduty, email, webhook, discord, teams, opsgenie
   - Methods: notifier (factory pattern), send_notification!, test!
   - Callbacks: generate_slug

5. **Notification** (`spec/models/notification_spec.rb`)
   - Associations: belongs_to alert, belongs_to incident, belongs_to notification_channel
   - Validations: notification_type, status, project_id
   - Scopes: pending, sent, failed, for_project
   - Status tracking: pending, sent, failed, skipped

6. **MaintenanceWindow** (`spec/models/maintenance_window_spec.rb`)
   - Validations: name, starts_at, ends_at, project_id, ends_after_starts
   - Scopes: active, current, for_project
   - Methods: currently_active?, covers_rule?
   - Time-based coverage logic

7. **OnCallSchedule** (`spec/models/on_call_schedule_spec.rb`)
   - Validations: name, slug, schedule_type, project_id
   - Schedule types: weekly, custom
   - Rotation types: daily, weekly
   - Methods: current_on_call_user, update_current_on_call!
   - Private: update_weekly_on_call!, update_rotation_on_call!

8. **EscalationPolicy** (`spec/models/escalation_policy_spec.rb`)
   - Associations: has_many alert_rules
   - Validations: name, slug, project_id
   - Scopes: enabled, for_project
   - Callbacks: generate_slug

9. **AlertHistory** (`spec/models/alert_history_spec.rb`)
   - Associations: belongs_to alert_rule
   - Query capabilities: timestamp, fingerprint, state filtering

### Controllers (1 test file)
1. **Api::V1::AlertsController** (`spec/controllers/api/v1/alerts_controller_spec.rb`)
   - GET #index: filtering by state, severity, acknowledgment, limit
   - GET #show: alert details with full data
   - POST #acknowledge: acknowledge alerts with notes
   - POST #trigger: manual alert creation
   - POST #resolve_by_name: bulk resolution
   - Authentication and authorization
   - Project isolation

### Jobs (2 test files)
1. **NotificationJob** (`spec/jobs/notification_job_spec.rb`)
   - Channel enabled/disabled logic
   - Alert rule muting checks
   - Maintenance window integration
   - Selective rule coverage
   - Retry behavior

2. **RuleEvaluationJob** (`spec/jobs/rule_evaluation_job_spec.rb`)
   - Single rule evaluation
   - Batch evaluation (all active rules)
   - Enabled/disabled/muted filtering
   - Error handling and logging
   - Continuation on failure

### Services (2 test files)
1. **AlertManager** (`spec/services/alert_manager_spec.rb`)
   - Alert lifecycle: pending → firing → resolved
   - Fingerprint-based alert lookup
   - Pending period enforcement
   - Resolve period enforcement
   - Alert history integration
   - State transition handling

2. **IncidentManager** (`spec/services/incident_manager_spec.rb`)
   - Incident creation on alert fire
   - Incident reuse for multiple alerts
   - Timeline event management
   - Auto-resolution when all alerts resolve
   - Alert-incident association

### Factories (9 factory files)
All models have comprehensive FactoryBot factories with traits:
- **alert_rules.rb**: critical, info, muted, disabled, anomaly, absence, composite, with_escalation_policy
- **alerts.rb**: firing, resolved, acknowledged, with_incident, with_labels
- **incidents.rb**: acknowledged, resolved, critical, info, with_affected_services
- **notification_channels.rb**: email, webhook, pagerduty, discord, teams, opsgenie, verified, disabled
- **notifications.rb**: sent, failed, skipped, for_incident
- **escalation_policies.rb**: with_repeat, disabled
- **maintenance_windows.rb**: current, past, future, inactive, recurring, with_rule_ids
- **on_call_schedules.rb**: custom, weekly_rotation, disabled
- **alert_histories.rb**: firing, with_labels

### Support Files
1. **api_helper.rb** - API authentication helpers and JSON parsing
2. **time_helpers.rb** - Time travel and freezing helpers
3. **sidekiq.rb** - Sidekiq testing setup and custom matchers

### Configuration Files
1. **rails_helper.rb** - RSpec Rails integration, FactoryBot, Sidekiq, Shoulda Matchers
2. **spec_helper.rb** - RSpec core configuration
3. **.rspec** - RSpec command-line defaults

## Coverage Highlights

### Validations
✅ All presence validations
✅ All inclusion validations
✅ All uniqueness validations (with scopes)
✅ Custom validations (e.g., ends_after_starts)

### Associations
✅ All belongs_to relationships
✅ All has_many relationships
✅ Dependent destroy/nullify behavior
✅ Optional associations

### Scopes
✅ Status scopes (active, enabled, open, etc.)
✅ Time-based scopes (current, recent)
✅ Project isolation scopes
✅ Complex query scopes (firing alerts, etc.)

### Business Logic
✅ State machines and transitions
✅ Timeline management
✅ Notification logic
✅ Muting and maintenance windows
✅ On-call rotation algorithms
✅ Alert fingerprinting and deduplication
✅ Incident auto-creation and resolution

### API Endpoints
✅ Authentication and authorization
✅ Project isolation
✅ Filtering and pagination
✅ Error handling (404, 401)
✅ Request/response serialization

### Background Jobs
✅ Job execution logic
✅ Conditional processing
✅ Error handling
✅ Batch processing
✅ Integration with models

### Edge Cases
✅ Nil/empty value handling
✅ Concurrent state changes
✅ Time-based expirations
✅ Missing associations
✅ Invalid state transitions
✅ Cross-project data leakage prevention

## Running the Tests

### First Time Setup
```bash
# Install dependencies
bundle install

# Set up test database
RAILS_ENV=test bundle exec rails db:create db:schema:load

# Run tests
bundle exec rspec
```

### Quick Script
```bash
chmod +x bin/test-setup
./bin/test-setup
```

### Common Commands
```bash
# Run all tests
bundle exec rspec

# Run with documentation format
bundle exec rspec --format documentation

# Run specific file
bundle exec rspec spec/models/alert_spec.rb

# Run specific test
bundle exec rspec spec/models/alert_spec.rb:18

# Run only model tests
bundle exec rspec spec/models

# Run with coverage (if SimpleCov added)
COVERAGE=true bundle exec rspec
```

## Test Quality Metrics

- **Isolation**: Each test is independent with proper factory setup
- **Clarity**: Descriptive context blocks and test names
- **Coverage**: All public methods and important private methods tested
- **Edge Cases**: Boundary conditions and error states covered
- **Performance**: Fast tests using transactional fixtures
- **Maintainability**: DRY factories and shared helpers

## Next Steps for Improvement

1. Add SimpleCov for code coverage metrics
2. Add request specs for full API integration tests
3. Add feature specs if frontend is developed
4. Add performance tests for rule evaluation at scale
5. Add contract tests for external integrations (Slack, PagerDuty, etc.)
6. Add mutation testing with Mutant
7. Add continuous integration setup (GitHub Actions, etc.)
