require "rails_helper"

RSpec.describe IncidentManager do
  let(:project) { create(:project) }
  let(:rule)    { create(:alert_rule, project: project, name: "High Error Rate") }
  let(:alert)   { create(:alert, project: project, alert_rule: rule, :firing) }
  let(:manager) { described_class.new(alert) }

  before do
    allow(NotificationJob).to receive(:perform_later)
  end

  # ────────────────────────────────
  # #fire!
  # ────────────────────────────────
  describe "#fire!" do
    context "when no open incident exists" do
      it "creates a new incident" do
        expect {
          manager.fire!
        }.to change(Incident, :count).by(1)
      end

      it "links the alert to the incident" do
        manager.fire!
        expect(alert.reload.incident).to be_present
      end

      it "sets incident title from rule name" do
        manager.fire!
        expect(Incident.last.title).to eq("High Error Rate")
      end

      it "sets incident severity from rule severity" do
        manager.fire!
        expect(Incident.last.severity).to eq(rule.severity)
      end

      it "sets incident status to triggered" do
        manager.fire!
        expect(Incident.last.status).to eq("triggered")
      end

      it "adds an initial timeline entry" do
        manager.fire!
        incident = Incident.last
        expect(incident.timeline).not_to be_empty
        expect(incident.timeline.first["type"]).to eq("triggered")
      end
    end

    context "when an open incident already exists for the rule" do
      let!(:existing_incident) do
        incident = create(:incident, project: project)
        alert_for_incident = create(:alert, project: project, alert_rule: rule,
                                    incident: incident, :firing)
        incident
      end

      it "does not create a new incident" do
        expect {
          manager.fire!
        }.not_to change(Incident, :count)
      end

      it "links the alert to the existing incident" do
        manager.fire!
        expect(alert.reload.incident).to eq(existing_incident)
      end

      it "adds an alert_fired timeline event to the existing incident" do
        original_count = existing_incident.timeline.length
        manager.fire!
        expect(existing_incident.reload.timeline.length).to be > original_count
      end
    end
  end

  # ────────────────────────────────
  # #resolve!
  # ────────────────────────────────
  describe "#resolve!" do
    context "when the alert has no incident" do
      let(:alert_no_incident) { create(:alert, project: project, alert_rule: rule, :firing) }
      let(:manager_no_incident) { described_class.new(alert_no_incident) }

      it "does nothing" do
        expect {
          manager_no_incident.resolve!
        }.not_to change(Incident, :count)
      end
    end

    context "when the alert has an incident" do
      let(:incident) { create(:incident, project: project) }

      before do
        alert.update!(incident: incident)
      end

      it "adds an alert_resolved timeline event" do
        manager.resolve!
        event = incident.reload.timeline.last
        expect(event["type"]).to eq("alert_resolved")
      end

      context "when all related alerts are resolved" do
        it "resolves the incident" do
          # alert is now resolved (no more firing alerts in incident)
          allow(incident.alerts).to receive(:firing).and_return(Alert.none)
          manager.resolve!
          expect(incident.reload.status).to eq("resolved")
        end
      end

      context "when other firing alerts remain in the incident" do
        it "leaves the incident open" do
          other_alert = create(:alert, project: project, alert_rule: rule,
                               incident: incident, :firing)
          manager.resolve!
          expect(incident.reload.status).not_to eq("resolved")
        end
      end
    end
  end
end
