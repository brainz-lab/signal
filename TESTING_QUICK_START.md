# Testing Quick Start Guide

## Prerequisites

Ensure you have:
- Ruby 3.x installed
- PostgreSQL running
- Bundler installed

## Setup (First Time)

### Option 1: Using the setup script
```bash
chmod +x bin/test-setup
./bin/test-setup
```

### Option 2: Manual setup
```bash
# Install dependencies
bundle install

# Create and prepare test database
RAILS_ENV=test bundle exec rails db:create
RAILS_ENV=test bundle exec rails db:schema:load

# Run tests
bundle exec rspec
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with documentation format
bundle exec rspec --format documentation

# Run specific file
bundle exec rspec spec/models/alert_spec.rb

# Run specific test (by line number)
bundle exec rspec spec/models/alert_spec.rb:45

# Run only model tests
bundle exec rspec spec/models

# Run only job tests
bundle exec rspec spec/jobs

# Run with seed for reproducibility
bundle exec rspec --seed 12345
```

## What's Been Tested

### ✅ Models (9 files, ~600+ examples)
- Alert - state transitions, notifications, acknowledgments
- AlertRule - evaluation, muting, all rule types
- Incident - lifecycle, timeline, resolution
- NotificationChannel - all channel types, testing
- Notification - statuses and delivery
- MaintenanceWindow - time-based coverage
- OnCallSchedule - rotation algorithms
- EscalationPolicy - policy management
- AlertHistory - historical tracking

### ✅ Controllers (1 file, ~15 examples)
- Api::V1::AlertsController - full CRUD and custom actions

### ✅ Jobs (2 files, ~25 examples)
- NotificationJob - delivery with business rules
- RuleEvaluationJob - single and batch evaluation

### ✅ Services (2 files, ~30 examples)
- AlertManager - alert lifecycle management
- IncidentManager - incident creation and resolution

### ✅ Factories
All models with comprehensive traits for easy test data creation

## Common Issues & Solutions

### Database Connection Error
```bash
# Ensure PostgreSQL is running
# Check config/database.yml settings
# Recreate test database
RAILS_ENV=test bundle exec rails db:drop db:create db:schema:load
```

### Missing Gems
```bash
# Install all dependencies
bundle install
```

### Pending Migrations
```bash
# Load latest schema
RAILS_ENV=test bundle exec rails db:schema:load
```

### Slow Tests
```bash
# Run in parallel (if parallel_tests gem added)
bundle exec parallel_rspec spec/
```

## Test Examples

### Using Factories
```ruby
# Create a firing alert
alert = create(:alert, :firing)

# Create with custom attributes
alert = create(:alert, project_id: 'custom-id')

# Build without saving
alert = build(:alert)

# Create with associations
alert = create(:alert, :with_incident)
```

### Time Helpers
```ruby
# Freeze time
freeze_time do
  # Your test
end

# Travel to specific time
travel_to 2.hours.from_now do
  # Your test
end
```

### API Testing
```ruby
# Set headers
request.headers.merge!(api_headers(project_id))

# Get JSON response
get :index
json = json_response
```

## Next Steps

1. Review TEST_COVERAGE_SUMMARY.md for detailed coverage info
2. Check spec/README.md for comprehensive documentation
3. Add more tests as you add new features
4. Consider adding SimpleCov for coverage reports
5. Set up CI/CD to run tests automatically

## Getting Help

- RSpec docs: https://rspec.info
- FactoryBot: https://github.com/thoughtbot/factory_bot
- Rails testing guide: https://guides.rubyonrails.org/testing.html
