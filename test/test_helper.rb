# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"

  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  add_group "Services", "app/services"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
  add_group "Channels", "app/channels"
end

ENV["RAILS_ENV"] ||= "test"
ENV["BRAINZLAB_SDK_ENABLED"] = "false"  # Disable SDK during tests to avoid database issues
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "mocha/minitest"

# Disable external network connections in tests
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Helper to create a valid project
    def create_project(platform_project_id: SecureRandom.uuid, name: "Test Project", environment: "live")
      Project.create!(
        platform_project_id: platform_project_id,
        name: name,
        environment: environment
      )
    end

    # Helper to create a valid alert rule
    def create_alert_rule(project:, **attrs)
      defaults = {
        name: "Test Rule #{SecureRandom.hex(4)}",
        description: "Test alert rule",
        rule_type: "threshold",
        source: "flux",
        source_name: "cpu_usage",
        operator: "gt",
        threshold: 80,
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
