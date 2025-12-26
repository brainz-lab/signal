require 'rails_helper'

RSpec.describe AlertRule, type: :model do
  describe 'associations' do
    it { should belong_to(:escalation_policy).optional }
    it { should have_many(:alerts).dependent(:destroy) }
    it { should have_many(:alert_histories).dependent(:destroy) }
  end

  describe 'validations' do
    subject { create(:alert_rule) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:slug) }
    it { should validate_presence_of(:source) }
    it { should validate_presence_of(:rule_type) }
    it { should validate_presence_of(:project_id) }

    it { should validate_inclusion_of(:source).in_array(%w[flux pulse reflex recall]) }
    it { should validate_inclusion_of(:rule_type).in_array(%w[threshold anomaly absence composite]) }
    it { should validate_inclusion_of(:severity).in_array(%w[info warning critical]) }

    it { should validate_uniqueness_of(:slug).scoped_to(:project_id) }
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'generates slug from name on create' do
        rule = build(:alert_rule, name: 'High CPU Usage', slug: nil)
        rule.valid?
        expect(rule.slug).to eq('high-cpu-usage')
      end

      it 'does not override existing slug' do
        rule = build(:alert_rule, name: 'High CPU', slug: 'custom-slug')
        rule.valid?
        expect(rule.slug).to eq('custom-slug')
      end
    end
  end

  describe 'scopes' do
    let(:project_id) { SecureRandom.uuid }
    let!(:enabled_rule) { create(:alert_rule, enabled: true, project_id: project_id) }
    let!(:disabled_rule) { create(:alert_rule, :disabled, project_id: project_id) }
    let!(:muted_rule) { create(:alert_rule, :muted, project_id: project_id) }
    let!(:muted_with_expiry) { create(:alert_rule, :muted_with_expiry, project_id: project_id) }

    describe '.enabled' do
      it 'returns only enabled rules' do
        expect(AlertRule.enabled).to include(enabled_rule, muted_rule, muted_with_expiry)
        expect(AlertRule.enabled).not_to include(disabled_rule)
      end
    end

    describe '.active' do
      it 'returns enabled and unmuted rules' do
        expect(AlertRule.active).to contain_exactly(enabled_rule)
      end
    end

    describe '.by_source' do
      let!(:flux_rule) { create(:alert_rule, source: 'flux') }
      let!(:pulse_rule) { create(:alert_rule, source: 'pulse') }

      it 'returns rules for specific source' do
        expect(AlertRule.by_source('flux')).to include(flux_rule)
        expect(AlertRule.by_source('flux')).not_to include(pulse_rule)
      end
    end

    describe '.firing' do
      let!(:firing_alert) { create(:alert, :firing, alert_rule: enabled_rule) }

      it 'returns rules with firing alerts' do
        expect(AlertRule.firing).to include(enabled_rule)
        expect(AlertRule.firing).not_to include(disabled_rule)
      end
    end

    describe '.for_project' do
      let(:other_project_id) { SecureRandom.uuid }
      let!(:other_rule) { create(:alert_rule, project_id: other_project_id) }

      it 'returns rules for specific project' do
        expect(AlertRule.for_project(project_id)).to include(enabled_rule)
        expect(AlertRule.for_project(project_id)).not_to include(other_rule)
      end
    end
  end

  describe '#evaluate!' do
    let(:rule) { create(:alert_rule) }
    let(:evaluator) { instance_double(RuleEvaluator) }
    let(:alert_manager) { instance_double(AlertManager) }
    let(:result) do
      {
        state: 'firing',
        value: 150.0,
        threshold: 100.0,
        fingerprint: 'test-fingerprint',
        labels: { host: 'server-01' }
      }
    end

    before do
      allow(RuleEvaluator).to receive(:new).with(rule).and_return(evaluator)
      allow(evaluator).to receive(:evaluate).and_return(result)
      allow(AlertManager).to receive(:new).with(rule).and_return(alert_manager)
      allow(alert_manager).to receive(:process)
    end

    it 'evaluates the rule using RuleEvaluator' do
      rule.evaluate!
      expect(evaluator).to have_received(:evaluate)
    end

    it 'updates last_evaluated_at and last_state' do
      freeze_time do
        rule.evaluate!
        expect(rule.last_evaluated_at).to be_within(1.second).of(Time.current)
        expect(rule.last_state).to eq('firing')
      end
    end

    it 'creates alert history record' do
      expect {
        rule.evaluate!
      }.to change(AlertHistory, :count).by(1)

      history = AlertHistory.last
      expect(history.alert_rule).to eq(rule)
      expect(history.state).to eq('firing')
      expect(history.value).to eq(150.0)
      expect(history.fingerprint).to eq('test-fingerprint')
    end

    it 'processes result with AlertManager' do
      rule.evaluate!
      expect(alert_manager).to have_received(:process).with(result)
    end

    it 'returns the evaluation result' do
      expect(rule.evaluate!).to eq(result)
    end
  end

  describe '#mute!' do
    let(:rule) { create(:alert_rule) }

    context 'without expiry' do
      it 'mutes the rule permanently' do
        rule.mute!(reason: 'Maintenance')
        expect(rule.muted).to be true
        expect(rule.muted_until).to be_nil
        expect(rule.muted_reason).to eq('Maintenance')
      end
    end

    context 'with expiry' do
      it 'mutes the rule until specified time' do
        until_time = 2.hours.from_now
        rule.mute!(until_time: until_time, reason: 'Testing')
        expect(rule.muted).to be true
        expect(rule.muted_until).to be_within(1.second).of(until_time)
      end
    end
  end

  describe '#unmute!' do
    let(:rule) { create(:alert_rule, :muted) }

    it 'unmutes the rule' do
      rule.unmute!
      expect(rule.muted).to be false
      expect(rule.muted_until).to be_nil
      expect(rule.muted_reason).to be_nil
    end
  end

  describe '#muted?' do
    context 'when not muted' do
      let(:rule) { create(:alert_rule) }

      it 'returns false' do
        expect(rule.muted?).to be false
      end
    end

    context 'when permanently muted' do
      let(:rule) { create(:alert_rule, :muted) }

      it 'returns true' do
        expect(rule.muted?).to be true
      end
    end

    context 'when muted with future expiry' do
      let(:rule) { create(:alert_rule, muted: true, muted_until: 1.hour.from_now) }

      it 'returns true' do
        expect(rule.muted?).to be true
      end
    end

    context 'when muted with past expiry' do
      let(:rule) { create(:alert_rule, muted: true, muted_until: 1.hour.ago) }

      it 'returns false' do
        expect(rule.muted?).to be false
      end
    end
  end

  describe '#notification_channels' do
    let(:channel1) { create(:notification_channel) }
    let(:channel2) { create(:notification_channel) }
    let(:rule) { create(:alert_rule, notify_channels: [channel1.id, channel2.id]) }

    it 'returns associated notification channels' do
      expect(rule.notification_channels).to contain_exactly(channel1, channel2)
    end
  end

  describe '#condition_description' do
    context 'threshold rule' do
      let(:rule) { create(:alert_rule, rule_type: 'threshold', aggregation: 'avg', operator: 'gt', threshold: 80, window: '5m') }

      it 'returns threshold description' do
        expect(rule.condition_description).to include('avg')
        expect(rule.condition_description).to include('>')
        expect(rule.condition_description).to include('80')
        expect(rule.condition_description).to include('5m')
      end
    end

    context 'anomaly rule' do
      let(:rule) { create(:alert_rule, :anomaly, sensitivity: 0.8, source_name: 'cpu_usage') }

      it 'returns anomaly description' do
        expect(rule.condition_description).to include('Anomaly')
        expect(rule.condition_description).to include('0.8')
      end
    end

    context 'absence rule' do
      let(:rule) { create(:alert_rule, :absence, expected_interval: '10m') }

      it 'returns absence description' do
        expect(rule.condition_description).to include('No data')
        expect(rule.condition_description).to include('10m')
      end
    end

    context 'composite rule' do
      let(:rule) { create(:alert_rule, :composite) }

      it 'returns composite description' do
        expect(rule.condition_description).to include('Composite')
        expect(rule.condition_description).to include('sub-rules')
      end
    end
  end
end
