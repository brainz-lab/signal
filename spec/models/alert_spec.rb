require 'rails_helper'

RSpec.describe Alert, type: :model do
  describe 'associations' do
    it { should belong_to(:alert_rule) }
    it { should belong_to(:incident).optional }
    it { should have_many(:notifications).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:fingerprint) }
    it { should validate_presence_of(:state) }
    it { should validate_presence_of(:project_id) }
    it { should validate_inclusion_of(:state).in_array(%w[pending firing resolved]) }
  end

  describe 'scopes' do
    let(:project_id) { SecureRandom.uuid }
    let!(:pending_alert) { create(:alert, state: 'pending', project_id: project_id) }
    let!(:firing_alert) { create(:alert, :firing, project_id: project_id) }
    let!(:resolved_alert) { create(:alert, :resolved, project_id: project_id) }
    let!(:acknowledged_alert) { create(:alert, :firing, :acknowledged, project_id: project_id) }

    describe '.active' do
      it 'returns pending and firing alerts' do
        expect(Alert.active).to include(pending_alert, firing_alert)
        expect(Alert.active).not_to include(resolved_alert)
      end
    end

    describe '.firing' do
      it 'returns only firing alerts' do
        expect(Alert.firing).to contain_exactly(firing_alert, acknowledged_alert)
      end
    end

    describe '.pending' do
      it 'returns only pending alerts' do
        expect(Alert.pending).to contain_exactly(pending_alert)
      end
    end

    describe '.resolved' do
      it 'returns only resolved alerts' do
        expect(Alert.resolved).to contain_exactly(resolved_alert)
      end
    end

    describe '.unacknowledged' do
      it 'returns only unacknowledged alerts' do
        expect(Alert.unacknowledged).to include(pending_alert, firing_alert, resolved_alert)
        expect(Alert.unacknowledged).not_to include(acknowledged_alert)
      end
    end

    describe '.for_project' do
      let(:other_project_id) { SecureRandom.uuid }
      let!(:other_alert) { create(:alert, project_id: other_project_id) }

      it 'returns alerts for specific project' do
        expect(Alert.for_project(project_id)).to include(pending_alert, firing_alert)
        expect(Alert.for_project(project_id)).not_to include(other_alert)
      end
    end

    describe '.recent' do
      it 'orders alerts by started_at descending' do
        expect(Alert.recent.first).to eq(resolved_alert)
      end
    end
  end

  describe '#fire!' do
    let(:alert) { create(:alert, state: 'pending') }
    let(:incident_manager) { instance_double(IncidentManager) }

    before do
      allow(IncidentManager).to receive(:new).with(alert).and_return(incident_manager)
      allow(incident_manager).to receive(:fire!)
      allow(alert).to receive(:notify!)
    end

    it 'updates state to firing' do
      alert.fire!
      expect(alert.state).to eq('firing')
    end

    it 'sets last_fired_at' do
      freeze_time do
        alert.fire!
        expect(alert.last_fired_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'creates or updates incident' do
      alert.fire!
      expect(incident_manager).to have_received(:fire!)
    end

    it 'sends notifications' do
      alert.fire!
      expect(alert).to have_received(:notify!).with(:alert_fired)
    end
  end

  describe '#resolve!' do
    let(:alert) { create(:alert, :firing) }
    let(:incident_manager) { instance_double(IncidentManager) }

    before do
      allow(IncidentManager).to receive(:new).with(alert).and_return(incident_manager)
      allow(incident_manager).to receive(:resolve!)
      allow(alert).to receive(:notify!)
    end

    it 'updates state to resolved' do
      alert.resolve!
      expect(alert.state).to eq('resolved')
    end

    it 'sets resolved_at' do
      freeze_time do
        alert.resolve!
        expect(alert.resolved_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'updates incident' do
      alert.resolve!
      expect(incident_manager).to have_received(:resolve!)
    end

    it 'sends resolution notification' do
      alert.resolve!
      expect(alert).to have_received(:notify!).with(:alert_resolved)
    end
  end

  describe '#acknowledge!' do
    let(:alert) { create(:alert, :firing) }
    let(:incident) { create(:incident) }

    context 'without incident' do
      it 'marks alert as acknowledged' do
        alert.acknowledge!(by: 'user1')
        expect(alert.acknowledged).to be true
        expect(alert.acknowledged_by).to eq('user1')
      end

      it 'sets acknowledgment timestamp' do
        freeze_time do
          alert.acknowledge!(by: 'user1')
          expect(alert.acknowledged_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'saves acknowledgment note' do
        alert.acknowledge!(by: 'user1', note: 'Working on it')
        expect(alert.acknowledgment_note).to eq('Working on it')
      end
    end

    context 'with incident' do
      before do
        alert.update!(incident: incident)
      end

      it 'acknowledges the incident' do
        expect(incident).to receive(:acknowledge!).with(by: 'user1')
        alert.acknowledge!(by: 'user1')
      end
    end
  end

  describe '#duration' do
    let(:alert) { create(:alert, started_at: 1.hour.ago) }

    context 'when alert is not resolved' do
      it 'returns duration from start to now' do
        expect(alert.duration).to be_within(1).of(3600)
      end
    end

    context 'when alert is resolved' do
      before { alert.update!(resolved_at: 30.minutes.ago) }

      it 'returns duration from start to resolution' do
        expect(alert.duration).to be_within(1).of(1800)
      end
    end
  end

  describe '#duration_human' do
    let(:alert) { create(:alert, started_at: 65.minutes.ago) }

    it 'returns human readable duration' do
      expect(alert.duration_human).to match(/1 hour/)
    end
  end

  describe '#severity' do
    let(:alert_rule) { create(:alert_rule, severity: 'critical') }
    let(:alert) { create(:alert, alert_rule: alert_rule) }

    it 'returns alert rule severity' do
      expect(alert.severity).to eq('critical')
    end
  end

  describe '#notify! (private method)' do
    let(:channel1) { create(:notification_channel) }
    let(:channel2) { create(:notification_channel) }
    let(:alert_rule) { create(:alert_rule, notify_channels: [channel1.id, channel2.id]) }
    let(:alert) { create(:alert, alert_rule: alert_rule) }

    context 'when rule is not muted' do
      it 'enqueues notification jobs for each channel' do
        alert.send(:notify!, :alert_fired)

        expect(NotificationJob).to have_been_enqueued.exactly(2).times
      end

      it 'updates notification tracking fields' do
        freeze_time do
          alert.send(:notify!, :alert_fired)
          alert.reload

          expect(alert.last_notified_at).to be_within(1.second).of(Time.current)
          expect(alert.notification_count).to eq(1)
        end
      end
    end

    context 'when rule is muted' do
      before { alert_rule.mute! }

      it 'does not send notifications' do
        alert.send(:notify!, :alert_fired)
        expect(NotificationJob).not_to have_been_enqueued
      end
    end
  end
end
