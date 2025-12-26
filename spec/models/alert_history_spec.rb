require 'rails_helper'

RSpec.describe AlertHistory, type: :model do
  describe 'associations' do
    it { should belong_to(:alert_rule) }
  end

  describe 'validations' do
    it 'creates a valid alert history record' do
      history = create(:alert_history)
      expect(history).to be_valid
    end
  end

  describe 'scopes and queries' do
    let(:project_id) { SecureRandom.uuid }
    let(:alert_rule) { create(:alert_rule, project_id: project_id) }
    let!(:history1) { create(:alert_history, alert_rule: alert_rule, timestamp: 5.minutes.ago) }
    let!(:history2) { create(:alert_history, alert_rule: alert_rule, timestamp: 2.minutes.ago) }

    it 'can be queried by timestamp' do
      recent = AlertHistory.where('timestamp > ?', 3.minutes.ago)
      expect(recent).to contain_exactly(history2)
    end

    it 'can be queried by alert_rule and fingerprint' do
      fingerprint = 'test-fingerprint'
      create(:alert_history, alert_rule: alert_rule, fingerprint: fingerprint)
      create(:alert_history, alert_rule: alert_rule, fingerprint: 'other-fingerprint')

      results = AlertHistory.where(alert_rule: alert_rule, fingerprint: fingerprint)
      expect(results.count).to eq(1)
    end
  end
end
