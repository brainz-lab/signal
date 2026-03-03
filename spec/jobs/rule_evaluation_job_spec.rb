require "rails_helper"

RSpec.describe RuleEvaluationJob, type: :job do
  describe "#perform" do
    let(:project) { create(:project) }
    let!(:rule)   { create(:alert_rule, project: project, enabled: true) }

    context "without a rule_id (all rules)" do
      it "calls evaluate! on all active enabled rules" do
        expect(rule).to receive(:evaluate!)
        allow(AlertRule).to receive(:active).and_return(AlertRule.where(id: rule.id))
        allow(AlertRule.active).to receive(:find_each).and_yield(rule)
        described_class.perform_now
      end

      it "does not raise when a rule evaluation fails" do
        allow(AlertRule).to receive(:active).and_return(AlertRule.where(id: rule.id))
        allow(rule).to receive(:evaluate!).and_raise(StandardError, "api timeout")

        expect { described_class.perform_now }.not_to raise_error
      end
    end

    context "with a specific rule_id" do
      it "evaluates only the specified rule" do
        expect(rule).to receive(:evaluate!)
        described_class.perform_now(rule.id)
      end

      it "does not evaluate a disabled rule" do
        rule.update!(enabled: false)
        expect(rule).not_to receive(:evaluate!)
        described_class.perform_now(rule.id)
      end

      it "does not evaluate a muted rule" do
        allow(rule).to receive(:muted?).and_return(true)
        expect(rule).not_to receive(:evaluate!)
        described_class.perform_now(rule.id)
      end

      it "raises ActiveRecord::RecordNotFound for a non-existent rule_id" do
        expect {
          described_class.perform_now("nonexistent-id")
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it "enqueues on the alerts queue" do
      expect(described_class.queue_name).to eq("alerts")
    end
  end
end
