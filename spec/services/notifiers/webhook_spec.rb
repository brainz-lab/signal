require "rails_helper"

RSpec.describe Notifiers::Webhook do
  let(:project)    { create(:project) }
  let(:webhook_url) { "https://example.com/webhook" }
  let(:channel)    { create(:notification_channel, :webhook, project: project,
                            config: { "url" => webhook_url }) }
  let(:rule)       { create(:alert_rule, project: project, notify_channels: []) }
  let(:alert)      { create(:alert, project: project, alert_rule: rule, :firing) }
  let(:notifier)   { described_class.new(channel) }

  before { allow(NotificationJob).to receive(:perform_later) }

  # ────────────────────────────────
  # #send! — success
  # ────────────────────────────────
  describe "#send!" do
    before do
      stub_request(:post, webhook_url).to_return(status: 200, body: '{"ok":true}')
    end

    it "POSTs to the configured URL" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(WebMock).to have_requested(:post, webhook_url)
    end

    it "returns success: true" do
      result = notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(result[:success]).to be true
    end

    it "sends the default payload structure" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      last_request = WebMock::RequestRegistry.instance.requested_signatures.to_a.last
      body = JSON.parse(last_request.body)
      expect(body).to include("event_type", "alert", "rule", "project_id")
      expect(body["event_type"]).to eq("alert_fired")
      expect(body["alert"]["fingerprint"]).to eq(alert.fingerprint)
    end
  end

  # ────────────────────────────────
  # #send! — failure
  # ────────────────────────────────
  describe "#send! when webhook returns error" do
    before do
      stub_request(:post, webhook_url).to_return(status: 500, body: "Server Error")
    end

    it "returns success: false" do
      result = notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(result[:success]).to be false
    end
  end

  # ────────────────────────────────
  # Custom HTTP method support
  # ────────────────────────────────
  describe "custom HTTP method" do
    let(:channel) do
      create(:notification_channel, :webhook, project: project,
             config: { "url" => webhook_url, "method" => "PUT" })
    end

    before { stub_request(:put, webhook_url).to_return(status: 200, body: "ok") }

    it "uses the configured HTTP method" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(WebMock).to have_requested(:put, webhook_url)
    end
  end
end
