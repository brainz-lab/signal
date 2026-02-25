require "rails_helper"

RSpec.describe Notifiers::Pagerduty do
  let(:project)      { create(:project) }
  let(:routing_key)  { "abc123def456abc123def456abc123de" }
  let(:channel)      { create(:notification_channel, :pagerduty, project: project,
                              config: { "routing_key" => routing_key }) }
  let(:rule)         { create(:alert_rule, project: project, :critical, notify_channels: []) }
  let(:alert)        { create(:alert, project: project, alert_rule: rule, :firing) }
  let(:notifier)     { described_class.new(channel) }
  let(:pd_api_url)   { "https://events.pagerduty.com/v2/enqueue" }

  before { allow(NotificationJob).to receive(:perform_later) }

  # ────────────────────────────────
  # #send! — trigger
  # ────────────────────────────────
  describe "#send! for alert_fired" do
    before do
      stub_request(:post, pd_api_url)
        .to_return(status: 202, body: '{"status":"success","dedup_key":"abc"}',
                   headers: { "Content-Type" => "application/json" })
    end

    it "POSTs to the PagerDuty Events API" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(WebMock).to have_requested(:post, pd_api_url)
    end

    it "returns success: true" do
      result = notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(result[:success]).to be true
    end

    it "sends trigger action" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      last_request = WebMock::RequestRegistry.instance.requested_signatures.to_a.last
      body = JSON.parse(last_request.body)
      expect(body["event_action"]).to eq("trigger")
      expect(body["routing_key"]).to eq(routing_key)
      expect(body["dedup_key"]).to eq(alert.fingerprint)
    end

    it "creates a sent Notification record" do
      expect {
        notifier.send!(alert: alert, notification_type: :alert_fired)
      }.to change(Notification, :count).by(1)
      expect(Notification.last.status).to eq("sent")
    end
  end

  # ────────────────────────────────
  # #send! — resolve
  # ────────────────────────────────
  describe "#send! for alert_resolved" do
    before do
      stub_request(:post, pd_api_url)
        .to_return(status: 202, body: '{"status":"success","dedup_key":"abc"}',
                   headers: { "Content-Type" => "application/json" })
    end

    it "sends resolve action" do
      notifier.send!(alert: alert, notification_type: :alert_resolved)
      last_request = WebMock::RequestRegistry.instance.requested_signatures.to_a.last
      body = JSON.parse(last_request.body)
      expect(body["event_action"]).to eq("resolve")
    end
  end

  # ────────────────────────────────
  # #send! — failure
  # ────────────────────────────────
  describe "#send! when PagerDuty returns error" do
    before do
      stub_request(:post, pd_api_url).to_return(status: 400, body: '{"error":"bad routing key"}')
    end

    it "returns success: false" do
      result = notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(result[:success]).to be false
    end

    it "records a failed Notification" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(Notification.last.status).to eq("failed")
    end
  end
end
