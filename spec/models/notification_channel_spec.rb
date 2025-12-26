require 'rails_helper'

RSpec.describe NotificationChannel, type: :model do
  describe 'associations' do
    it { should have_many(:notifications).dependent(:destroy) }
  end

  describe 'validations' do
    subject { create(:notification_channel) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:slug) }
    it { should validate_presence_of(:channel_type) }
    it { should validate_presence_of(:project_id) }

    it { should validate_inclusion_of(:channel_type).in_array(%w[slack pagerduty email webhook discord teams opsgenie]) }
    it { should validate_uniqueness_of(:slug).scoped_to(:project_id) }
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'generates slug from name on create' do
        channel = build(:notification_channel, name: 'Production Slack', slug: nil)
        channel.valid?
        expect(channel.slug).to eq('production-slack')
      end

      it 'does not override existing slug' do
        channel = build(:notification_channel, name: 'Slack', slug: 'custom-slug')
        channel.valid?
        expect(channel.slug).to eq('custom-slug')
      end
    end
  end

  describe 'scopes' do
    let(:project_id) { SecureRandom.uuid }
    let!(:enabled_channel) { create(:notification_channel, enabled: true, project_id: project_id) }
    let!(:disabled_channel) { create(:notification_channel, :disabled, project_id: project_id) }

    describe '.enabled' do
      it 'returns only enabled channels' do
        expect(NotificationChannel.enabled).to include(enabled_channel)
        expect(NotificationChannel.enabled).not_to include(disabled_channel)
      end
    end

    describe '.for_project' do
      let(:other_project_id) { SecureRandom.uuid }
      let!(:other_channel) { create(:notification_channel, project_id: other_project_id) }

      it 'returns channels for specific project' do
        expect(NotificationChannel.for_project(project_id)).to include(enabled_channel)
        expect(NotificationChannel.for_project(project_id)).not_to include(other_channel)
      end
    end
  end

  describe '#notifier' do
    it 'returns Slack notifier for slack channel' do
      channel = create(:notification_channel, channel_type: 'slack')
      expect(channel.notifier).to be_a(Notifiers::Slack)
    end

    it 'returns Pagerduty notifier for pagerduty channel' do
      channel = create(:notification_channel, :pagerduty)
      expect(channel.notifier).to be_a(Notifiers::Pagerduty)
    end

    it 'returns Email notifier for email channel' do
      channel = create(:notification_channel, :email)
      expect(channel.notifier).to be_a(Notifiers::Email)
    end

    it 'returns Webhook notifier for webhook channel' do
      channel = create(:notification_channel, :webhook)
      expect(channel.notifier).to be_a(Notifiers::Webhook)
    end

    it 'returns Discord notifier for discord channel' do
      channel = create(:notification_channel, :discord)
      expect(channel.notifier).to be_a(Notifiers::Discord)
    end

    it 'returns Teams notifier for teams channel' do
      channel = create(:notification_channel, :teams)
      expect(channel.notifier).to be_a(Notifiers::Teams)
    end

    it 'returns Opsgenie notifier for opsgenie channel' do
      channel = create(:notification_channel, :opsgenie)
      expect(channel.notifier).to be_a(Notifiers::Opsgenie)
    end
  end

  describe '#send_notification!' do
    let(:channel) { create(:notification_channel) }
    let(:alert) { create(:alert) }
    let(:notifier) { instance_double(Notifiers::Slack) }

    before do
      allow(channel).to receive(:notifier).and_return(notifier)
      allow(notifier).to receive(:send!)
    end

    it 'delegates to notifier' do
      channel.send_notification!(alert: alert, notification_type: :alert_fired)
      expect(notifier).to have_received(:send!).with(alert: alert, notification_type: :alert_fired)
    end
  end

  describe '#test!' do
    let(:channel) { create(:notification_channel) }
    let(:notifier) { instance_double(Notifiers::Slack) }

    before do
      allow(channel).to receive(:notifier).and_return(notifier)
    end

    context 'when test succeeds' do
      before do
        allow(notifier).to receive(:test!).and_return({ success: true, message: 'OK' })
      end

      it 'updates test status to success' do
        freeze_time do
          result = channel.test!

          expect(result[:success]).to be true
          expect(channel.last_test_status).to eq('success')
          expect(channel.last_tested_at).to be_within(1.second).of(Time.current)
          expect(channel.verified).to be true
        end
      end
    end

    context 'when test fails' do
      before do
        allow(notifier).to receive(:test!).and_return({ success: false, error: 'Connection failed' })
      end

      it 'updates test status to failed' do
        freeze_time do
          result = channel.test!

          expect(result[:success]).to be false
          expect(channel.last_test_status).to eq('failed')
          expect(channel.last_tested_at).to be_within(1.second).of(Time.current)
          expect(channel.verified).to be false
        end
      end
    end
  end
end
