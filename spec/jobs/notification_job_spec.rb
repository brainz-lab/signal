require "rails_helper"

RSpec.describe NotificationJob, type: :job do
  describe "#perform" do
    let(:project) { create(:project) }
    let(:rule)    { create(:alert_rule, project: project, enabled: true) }
    let(:channel) { create(:notification_channel, project: project, enabled: true) }
    let(:alert)   { create(:alert, project: project, alert_rule: rule) }

    before do
      # No active maintenance windows by default
      allow(MaintenanceWindow).to receive_message_chain(:for_project, :active, :current).and_return([])
    end

    it "sends a notification via the channel" do
      expect(channel).to receive(:send_notification!).with(
        alert: alert,
        notification_type: :triggered
      )
      described_class.perform_now(
        channel_id: channel.id,
        alert_id: alert.id,
        notification_type: "triggered"
      )
    end

    it "skips sending when the channel is disabled" do
      channel.update!(enabled: false)
      expect(channel).not_to receive(:send_notification!)
      described_class.perform_now(
        channel_id: channel.id,
        alert_id: alert.id,
        notification_type: "triggered"
      )
    end

    it "skips sending when the alert rule is muted" do
      allow(rule).to receive(:muted?).and_return(true)
      expect(channel).not_to receive(:send_notification!)
      described_class.perform_now(
        channel_id: channel.id,
        alert_id: alert.id,
        notification_type: "triggered"
      )
    end

    it "skips sending during an active maintenance window" do
      window = instance_double(MaintenanceWindow, covers_rule?: true)
      allow(MaintenanceWindow).to receive_message_chain(:for_project, :active, :current).and_return([window])
      expect(channel).not_to receive(:send_notification!)
      described_class.perform_now(
        channel_id: channel.id,
        alert_id: alert.id,
        notification_type: "triggered"
      )
    end

    it "enqueues on the notifications queue" do
      expect(described_class.queue_name).to eq("notifications")
    end
  end
end
