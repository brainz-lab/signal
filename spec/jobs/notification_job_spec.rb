require 'rails_helper'

RSpec.describe NotificationJob, type: :job do
  let(:project_id) { SecureRandom.uuid }
  let(:channel) { create(:notification_channel, enabled: true, project_id: project_id) }
  let(:alert_rule) { create(:alert_rule, project_id: project_id) }
  let(:alert) { create(:alert, :firing, alert_rule: alert_rule, project_id: project_id) }

  describe '#perform' do
    context 'with enabled channel and active alert' do
      it 'sends notification through the channel' do
        expect(channel).to receive(:send_notification!).with(
          alert: alert,
          notification_type: :alert_fired
        )

        described_class.new.perform(
          channel_id: channel.id,
          alert_id: alert.id,
          notification_type: 'alert_fired'
        )
      end
    end

    context 'when channel is disabled' do
      before { channel.update!(enabled: false) }

      it 'does not send notification' do
        expect(channel).not_to receive(:send_notification!)

        described_class.new.perform(
          channel_id: channel.id,
          alert_id: alert.id,
          notification_type: 'alert_fired'
        )
      end
    end

    context 'when alert rule is muted' do
      before { alert_rule.mute! }

      it 'does not send notification' do
        expect(channel).not_to receive(:send_notification!)

        described_class.new.perform(
          channel_id: channel.id,
          alert_id: alert.id,
          notification_type: 'alert_fired'
        )
      end
    end

    context 'when in maintenance window' do
      let!(:maintenance_window) do
        create(:maintenance_window, :current,
          project_id: project_id,
          rule_ids: [alert_rule.id]
        )
      end

      it 'does not send notification' do
        expect(channel).not_to receive(:send_notification!)

        described_class.new.perform(
          channel_id: channel.id,
          alert_id: alert.id,
          notification_type: 'alert_fired'
        )
      end
    end

    context 'when maintenance window does not cover the rule' do
      let!(:maintenance_window) do
        create(:maintenance_window, :current,
          project_id: project_id,
          rule_ids: [SecureRandom.uuid] # Different rule
        )
      end

      it 'sends notification' do
        expect(channel).to receive(:send_notification!).with(
          alert: alert,
          notification_type: :alert_fired
        )

        described_class.new.perform(
          channel_id: channel.id,
          alert_id: alert.id,
          notification_type: 'alert_fired'
        )
      end
    end

    context 'when maintenance window covers all rules (empty rule_ids)' do
      let!(:maintenance_window) do
        create(:maintenance_window, :current,
          project_id: project_id,
          rule_ids: [] # Covers all rules
        )
      end

      it 'does not send notification' do
        expect(channel).not_to receive(:send_notification!)

        described_class.new.perform(
          channel_id: channel.id,
          alert_id: alert.id,
          notification_type: 'alert_fired'
        )
      end
    end
  end

  describe 'retry behavior' do
    it 'retries on StandardError' do
      expect(described_class).to have_been_enqueued.on_queue('notifications')
    end
  end
end
