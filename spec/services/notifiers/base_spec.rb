require "rails_helper"

# Concrete subclass for testing Base behaviour
class TestNotifier < Notifiers::Base
  def deliver!(payload)
    { status: 200, ok: true }
  end

  def build_payload(alert, notification_type)
    { event: notification_type.to_s, alert_id: alert.id }
  end

  def build_test_payload
    { event: "test" }
  end
end

class FailingNotifier < Notifiers::Base
  def deliver!(_payload)
    raise "Delivery failed"
  end

  def build_payload(_alert, _notification_type)
    { event: "fail" }
  end

  def build_test_payload
    { event: "test" }
  end
end

RSpec.describe Notifiers::Base do
  let(:project) { create(:project) }
  let(:channel) { create(:notification_channel, :webhook, project: project) }
  let(:rule)    { create(:alert_rule, project: project, notify_channels: []) }
  let(:alert)   { create(:alert, project: project, alert_rule: rule, :firing) }

  before { allow(NotificationJob).to receive(:perform_later) }

  # ────────────────────────────────
  # #send! — success path
  # ────────────────────────────────
  describe "#send!" do
    let(:notifier) { TestNotifier.new(channel) }

    it "returns success: true" do
      result = notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(result[:success]).to be true
    end

    it "creates a Notification record with status sent" do
      expect {
        notifier.send!(alert: alert, notification_type: :alert_fired)
      }.to change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.status).to eq("sent")
      expect(notification.notification_type).to eq("alert_fired")
      expect(notification.alert).to eq(alert)
      expect(notification.notification_channel).to eq(channel)
    end

    it "increments success_count on the channel" do
      expect {
        notifier.send!(alert: alert, notification_type: :alert_fired)
      }.to change { channel.reload.success_count }.by(1)
    end

    it "updates last_used_at on the channel" do
      Timecop.freeze do
        notifier.send!(alert: alert, notification_type: :alert_fired)
        expect(channel.reload.last_used_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  # ────────────────────────────────
  # #send! — failure path
  # ────────────────────────────────
  describe "#send! with delivery failure" do
    let(:failing_notifier) { FailingNotifier.new(channel) }

    it "returns success: false with error message" do
      result = failing_notifier.send!(alert: alert, notification_type: :alert_fired)
      expect(result[:success]).to be false
      expect(result[:error]).to eq("Delivery failed")
    end

    it "creates a failed Notification record" do
      expect {
        failing_notifier.send!(alert: alert, notification_type: :alert_fired)
      }.to change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.status).to eq("failed")
      expect(notification.error_message).to eq("Delivery failed")
    end

    it "increments failure_count on the channel" do
      expect {
        failing_notifier.send!(alert: alert, notification_type: :alert_fired)
      }.to change { channel.reload.failure_count }.by(1)
    end
  end

  # ────────────────────────────────
  # #test!
  # ────────────────────────────────
  describe "#test!" do
    let(:notifier) { TestNotifier.new(channel) }

    it "returns success: true" do
      result = notifier.test!
      expect(result[:success]).to be true
    end

    it "returns an error on failure" do
      failing = FailingNotifier.new(channel)
      result = failing.test!
      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end
  end
end
