require "rails_helper"

RSpec.describe Notifiers::Slack do
  let(:project)    { create(:project) }
  let(:channel)    { create(:notification_channel, :slack, project: project) }
  let(:rule)       { create(:alert_rule, project: project, :critical, notify_channels: []) }
  let(:alert)      { create(:alert, project: project, alert_rule: rule, :firing, current_value: 8.5) }
  let(:notifier)   { described_class.new(channel) }
  let(:webhook_url) { channel.config["webhook_url"] }

  before { allow(NotificationJob).to receive(:perform_later) }

  # ────────────────────────────────
  # #send! with WebMock
  # ────────────────────────────────
  describe "#send!" do
    before do
      stub_request(:post, webhook_url).to_return(status: 200, body: "ok")
    end

    it "posts to the Slack webhook URL" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(WebMock).to have_requested(:post, webhook_url)
    end

    it "returns success: true" do
      result = notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(result[:success]).to be true
    end

    it "creates a sent Notification record" do
      expect {
        notifier.send!(alert: alert, notification_type: :alert_fired)
      }.to change(Notification, :count).by(1)
      expect(Notification.last.status).to eq("sent")
    end
  end

  describe "#send! when Slack returns an error" do
    before do
      stub_request(:post, webhook_url).to_return(status: 400, body: "Bad payload")
    end

    it "returns success: false" do
      result = notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(result[:success]).to be false
    end

    it "creates a failed Notification record" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(Notification.last.status).to eq("failed")
    end
  end

  # ────────────────────────────────
  # build_payload color/emoji
  # ────────────────────────────────
  describe "build_payload" do
    before { stub_request(:post, webhook_url).to_return(status: 200, body: "ok") }

    it "uses red color for critical severity" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      request_body = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.to_a.last.body)
      expect(request_body["attachments"].first["color"]).to eq("#FF0000")
    end

    it "includes FIRING in the title for alert_fired" do
      notifier.send!(alert: alert, notification_type: :alert_fired)
      request_body = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.to_a.last.body)
      expect(request_body["attachments"].first["title"]).to include("FIRING")
    end

    it "includes RESOLVED in the title for alert_resolved" do
      notifier.send!(alert: alert, notification_type: :alert_resolved)
      request_body = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.to_a.last.body)
      expect(request_body["attachments"].first["title"]).to include("RESOLVED")
    end
  end
end
