ENV["RAILS_ENV"] ||= "test"
ENV["BRAINZLAB_SDK_ENABLED"] = "false"  # Disable SDK during tests to avoid database issues
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Helper to create a valid project
    def create_project(platform_project_id: "prj_#{SecureRandom.hex(8)}", name: "Test Project", environment: "live")
      Project.create!(
        platform_project_id: platform_project_id,
        name: name,
        environment: environment
      )
    end

    # Helper to create a valid alert rule
    def create_alert_rule(project:, **attrs)
      defaults = {
        name: "Test Rule",
        description: "Test alert rule",
        rule_type: "threshold",
        data_source: "flux",
        query: "metric:cpu_usage",
        condition_operator: "gt",
        condition_value: 80,
        severity: "warning",
        enabled: true,
        evaluation_interval: 60
      }

      project.alert_rules.create!(defaults.merge(attrs))
    end

    # Helper to create a valid alert
    def create_alert(alert_rule:, **attrs)
      defaults = {
        project: alert_rule.project,
        status: "firing",
        severity: alert_rule.severity,
        triggered_at: Time.current,
        message: "Alert triggered: #{alert_rule.name}"
      }

      alert_rule.alerts.create!(defaults.merge(attrs))
    end

    # Helper to create a notification channel
    def create_notification_channel(project:, **attrs)
      defaults = {
        name: "Test Slack Channel",
        channel_type: "slack",
        config: { webhook_url: "https://hooks.slack.com/test" },
        enabled: true
      }

      project.notification_channels.create!(defaults.merge(attrs))
    end
  end
end

# Stub PlatformClient for tests
class PlatformClient
  def self.validate_key(api_key)
    if api_key == "valid_key"
      {
        valid: true,
        project_id: "prj_test123",
        project_name: "Test Project",
        environment: "live",
        features: { signal: true }
      }
    elsif api_key&.start_with?("sig_")
      nil # Will be handled by find_project_by_api_key
    else
      { valid: false }
    end
  end

  def self.track_usage(project_id:, product:, metric:, count:)
    # Stub - do nothing in tests
    true
  end

  def self.get_project_config(platform_project_id:)
    {
      name: "Test Project",
      environment: "live"
    }
  end
end
