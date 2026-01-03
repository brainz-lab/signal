# frozen_string_literal: true

require "test_helper"

class Notifiers::SlackTest < ActiveSupport::TestCase
  setup do
    project = projects(:acme)
    @channel = NotificationChannel.create!(
      project: project,
      name: "Slack Test Channel",
      channel_type: "slack",
      config: { webhook_url: "https://hooks.slack.com/services/test", channel: "#alerts" }
    )
    rule = alert_rules(:cpu_threshold)
    @alert = rule.alerts.create!(
      project: project,
      fingerprint: "slack_test_#{SecureRandom.hex(8)}",
      state: "firing",
      started_at: Time.current,
      current_value: 95.0
    )
    @notifier = Notifiers::Slack.new(@channel)
  end

  # Initialization
  test "initializes with slack channel" do
    notifier = Notifiers::Slack.new(@channel)
    assert_not_nil notifier
  end

  # Payload building
  test "builds payload with correct structure" do
    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    assert payload.is_a?(Hash)
    assert_equal "#alerts", payload[:channel]
    assert_equal "Brainz Lab Signal", payload[:username]
    assert_equal ":bell:", payload[:icon_emoji]
    assert payload[:attachments].is_a?(Array)
  end

  test "builds payload with firing emoji for alert_fired" do
    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    title = payload[:attachments].first[:title]
    assert_includes title, "🔴"
    assert_includes title, "FIRING"
  end

  test "builds payload with resolved emoji for alert_resolved" do
    payload = @notifier.send(:build_payload, @alert, :alert_resolved)

    title = payload[:attachments].first[:title]
    assert_includes title, "🟢"
    assert_includes title, "RESOLVED"
  end

  test "builds payload with red color for critical severity" do
    rule = @alert.alert_rule
    rule.update!(severity: "critical")

    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    assert_equal "#FF0000", payload[:attachments].first[:color]
  end

  test "builds payload with orange color for warning severity" do
    rule = @alert.alert_rule
    rule.update!(severity: "warning")

    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    assert_equal "#FFA500", payload[:attachments].first[:color]
  end

  test "builds payload with blue color for info severity" do
    rule = @alert.alert_rule
    rule.update!(severity: "info")

    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    assert_equal "#36A2EB", payload[:attachments].first[:color]
  end

  test "builds payload with correct fields" do
    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    fields = payload[:attachments].first[:fields]
    field_titles = fields.map { |f| f[:title] }

    assert_includes field_titles, "Severity"
    assert_includes field_titles, "Value"
    assert_includes field_titles, "Duration"
    assert_includes field_titles, "Source"
  end

  test "builds payload with action buttons" do
    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    actions = payload[:attachments].first[:actions]
    assert actions.is_a?(Array)
    assert_equal 2, actions.size

    action_texts = actions.map { |a| a[:text] }
    assert_includes action_texts, "View Alert"
    assert_includes action_texts, "Acknowledge"
  end

  test "builds payload with rule condition description" do
    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    text = payload[:attachments].first[:text]
    assert_equal @alert.alert_rule.condition_description, text
  end

  # Test payload
  test "builds test payload with simple message" do
    payload = @notifier.send(:build_test_payload)

    assert payload.is_a?(Hash)
    assert_equal "#alerts", payload[:channel]
    assert_includes payload[:text], "Test notification"
    assert_includes payload[:text], "working"
  end

  # URL generation
  test "generates correct alert URL" do
    ENV["SIGNAL_URL"] = "https://test-signal.example.com"

    payload = @notifier.send(:build_payload, @alert, :alert_fired)
    view_action = payload[:attachments].first[:actions].find { |a| a[:text] == "View Alert" }

    assert_includes view_action[:url], @alert.id
    assert_includes view_action[:url], "https://test-signal.example.com"
  ensure
    ENV.delete("SIGNAL_URL")
  end

  test "generates correct acknowledge URL" do
    ENV["SIGNAL_URL"] = "https://test-signal.example.com"

    payload = @notifier.send(:build_payload, @alert, :alert_fired)
    ack_action = payload[:attachments].first[:actions].find { |a| a[:text] == "Acknowledge" }

    assert_includes ack_action[:url], @alert.id
    assert_includes ack_action[:url], "acknowledge"
  ensure
    ENV.delete("SIGNAL_URL")
  end

  # Delivery (with stubbing)
  test "sends HTTP POST to webhook URL" do
    stub_request(:post, "https://hooks.slack.com/services/test")
      .to_return(status: 200, body: "ok")

    result = @notifier.send!(alert: @alert, notification_type: :alert_fired)

    assert result[:success]
    assert_requested :post, "https://hooks.slack.com/services/test"
  end

  test "raises error on non-success response" do
    stub_request(:post, "https://hooks.slack.com/services/test")
      .to_return(status: 500, body: "Internal Server Error")

    result = @notifier.send!(alert: @alert, notification_type: :alert_fired)

    assert_not result[:success]
    assert_includes result[:error], "Slack error"
  end

  test "test! sends test payload" do
    stub_request(:post, "https://hooks.slack.com/services/test")
      .to_return(status: 200, body: "ok")

    result = @notifier.test!

    assert result[:success]
    assert_requested :post, "https://hooks.slack.com/services/test"
  end

  # Timestamp
  test "includes timestamp in payload" do
    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    ts = payload[:attachments].first[:ts]
    assert ts.is_a?(Integer)
    assert ts > 0
  end

  # Footer
  test "includes Brainz Lab footer" do
    payload = @notifier.send(:build_payload, @alert, :alert_fired)

    footer = payload[:attachments].first[:footer]
    assert_equal "Brainz Lab Signal", footer
  end
end
