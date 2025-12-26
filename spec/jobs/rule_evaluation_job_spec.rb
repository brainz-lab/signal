require 'rails_helper'

RSpec.describe RuleEvaluationJob, type: :job do
  let(:project_id) { SecureRandom.uuid }
  let(:rule) { create(:alert_rule, enabled: true, project_id: project_id) }

  describe '#perform' do
    context 'with specific rule_id' do
      it 'evaluates the specific rule' do
        expect(rule).to receive(:evaluate!)
        described_class.new.perform(rule.id)
      end

      context 'when rule is disabled' do
        before { rule.update!(enabled: false) }

        it 'does not evaluate the rule' do
          expect(rule).not_to receive(:evaluate!)
          described_class.new.perform(rule.id)
        end
      end

      context 'when rule is muted' do
        before { rule.mute! }

        it 'does not evaluate the rule' do
          expect(rule).not_to receive(:evaluate!)
          described_class.new.perform(rule.id)
        end
      end
    end

    context 'without rule_id' do
      let!(:enabled_rule1) { create(:alert_rule, enabled: true, project_id: project_id) }
      let!(:enabled_rule2) { create(:alert_rule, enabled: true, project_id: project_id) }
      let!(:disabled_rule) { create(:alert_rule, :disabled, project_id: project_id) }
      let!(:muted_rule) { create(:alert_rule, :muted, project_id: project_id) }

      it 'evaluates all active rules' do
        allow_any_instance_of(AlertRule).to receive(:evaluate!)

        described_class.new.perform

        expect(enabled_rule1).to have_received(:evaluate!)
        expect(enabled_rule2).to have_received(:evaluate!)
      end

      it 'does not evaluate disabled or muted rules' do
        allow_any_instance_of(AlertRule).to receive(:evaluate!)

        described_class.new.perform

        expect(disabled_rule).not_to have_received(:evaluate!)
        expect(muted_rule).not_to have_received(:evaluate!)
      end

      it 'continues evaluation even if one rule fails' do
        allow(enabled_rule1).to receive(:evaluate!).and_raise(StandardError, 'Test error')
        allow(enabled_rule2).to receive(:evaluate!)

        expect {
          described_class.new.perform
        }.not_to raise_error

        expect(enabled_rule2).to have_received(:evaluate!)
      end

      it 'logs errors for failed rules' do
        allow(enabled_rule1).to receive(:evaluate!).and_raise(StandardError, 'Test error')
        allow(Rails.logger).to receive(:error)

        described_class.new.perform

        expect(Rails.logger).to have_received(:error).with(/Error evaluating rule.*Test error/)
      end
    end
  end
end
