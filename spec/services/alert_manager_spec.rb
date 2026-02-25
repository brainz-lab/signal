require "rails_helper"

RSpec.describe AlertManager do
  let(:project)   { create(:project) }
  let(:rule)      { create(:alert_rule, project: project, pending_period: 0, resolve_period: 300) }
  let(:manager)   { described_class.new(rule) }

  def result_for(state, value: 5.5, fingerprint: "fp-abc")
    { state: state, value: value, threshold: rule.threshold,
      fingerprint: fingerprint, labels: {} }
  end

  before do
    allow(IncidentManager).to receive_message_chain(:new, :fire!)
    allow(IncidentManager).to receive_message_chain(:new, :resolve!)
    allow(NotificationJob).to receive(:perform_later)
  end

  # ────────────────────────────────
  # Firing path
  # ────────────────────────────────
  describe "#process with firing result" do
    context "when no alert exists yet (new alert)" do
      it "creates a pending alert" do
        expect {
          manager.process(result_for("firing"))
        }.to change(Alert, :count).by(1)

        alert = Alert.last
        expect(alert.state).to eq("pending")
      end
    end

    context "when pending_period is 0 (fire immediately)" do
      it "transitions the alert to firing right away" do
        manager.process(result_for("firing"))
        alert = Alert.last
        expect(alert.state).to eq("firing")
      end
    end

    context "when pending_period > 0 and alert started recently" do
      let(:rule) { create(:alert_rule, project: project, pending_period: 300) }

      it "keeps the alert in pending" do
        manager.process(result_for("firing"))
        expect(Alert.last.state).to eq("pending")
      end
    end

    context "when pending_period > 0 and alert started long enough ago" do
      let(:rule) { create(:alert_rule, project: project, pending_period: 60) }

      it "transitions the alert from pending to firing" do
        alert = create(:alert, project: project, alert_rule: rule,
                       fingerprint: "fp-abc", state: "pending",
                       started_at: 2.minutes.ago)
        manager.process(result_for("firing", fingerprint: "fp-abc"))
        expect(alert.reload.state).to eq("firing")
      end
    end

    context "when alert is already firing" do
      it "updates last_fired_at without re-triggering" do
        alert = create(:alert, project: project, alert_rule: rule,
                       fingerprint: "fp-abc", :firing)
        expect(IncidentManager).not_to receive(:new)
        expect {
          manager.process(result_for("firing", fingerprint: "fp-abc"))
        }.not_to change(Alert, :count)

        expect(alert.reload.last_fired_at).to be_within(2.seconds).of(Time.current)
      end
    end

    context "when alert was previously resolved" do
      it "resets the alert to pending" do
        alert = create(:alert, project: project, alert_rule: rule,
                       fingerprint: "fp-abc", :resolved)
        manager.process(result_for("firing", fingerprint: "fp-abc"))
        expect(alert.reload.state).to eq("pending")
        expect(alert.resolved_at).to be_nil
      end
    end
  end

  # ────────────────────────────────
  # OK path
  # ────────────────────────────────
  describe "#process with ok result" do
    context "when no existing alert" do
      it "does nothing" do
        expect {
          manager.process(result_for("ok", fingerprint: "fp-nonexistent"))
        }.not_to change(Alert, :count)
      end
    end

    context "when alert is pending" do
      it "destroys the pending alert" do
        alert = create(:alert, project: project, alert_rule: rule,
                       fingerprint: "fp-abc", :pending)
        manager.process(result_for("ok", fingerprint: "fp-abc"))
        expect(Alert.exists?(alert.id)).to be false
      end
    end

    context "when alert is firing and ok long enough" do
      it "resolves the alert" do
        alert = create(:alert, project: project, alert_rule: rule,
                       fingerprint: "fp-abc", :firing)
        # No recent history → ok_long_enough? returns true (empty array, all? → true)
        allow(IncidentManager).to receive_message_chain(:new, :resolve!)
        manager.process(result_for("ok", fingerprint: "fp-abc"))
        expect(alert.reload.state).to eq("resolved")
      end
    end

    context "when alert is firing but recent history has firing entries" do
      it "does not resolve the alert yet" do
        alert = create(:alert, project: project, alert_rule: rule,
                       fingerprint: "fp-abc", :firing)
        create(:alert_history, :firing, project: project, alert_rule: rule,
               fingerprint: "fp-abc", timestamp: 1.minute.ago)
        manager.process(result_for("ok", fingerprint: "fp-abc"))
        expect(alert.reload.state).to eq("firing")
      end
    end
  end

  # ────────────────────────────────
  # Private helpers (tested via process)
  # ────────────────────────────────
  describe "pending_long_enough?" do
    context "with pending_period = 0" do
      it "always returns true (fire immediately)" do
        rule_zero = create(:alert_rule, project: project, pending_period: 0)
        mgr = described_class.new(rule_zero)
        alert = create(:alert, project: project, alert_rule: rule_zero, :pending,
                       started_at: Time.current)
        mgr.process({ state: "firing", value: 10, threshold: 5,
                      fingerprint: alert.fingerprint, labels: {} })
        expect(alert.reload.state).to eq("firing")
      end
    end
  end
end
