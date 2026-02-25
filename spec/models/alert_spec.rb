require "rails_helper"

RSpec.describe Alert, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:alert_rule) }
  it { is_expected.to belong_to(:incident).optional }
  it { is_expected.to have_many(:notifications).dependent(:destroy) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:fingerprint) }
  it { is_expected.to validate_presence_of(:state) }
  it { is_expected.to validate_inclusion_of(:state).in_array(%w[pending firing resolved]) }

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let(:project)  { create(:project) }
    let(:rule)     { create(:alert_rule, project: project) }

    let!(:pending_alert)  { create(:alert, project: project, alert_rule: rule, :pending) }
    let!(:firing_alert)   { create(:alert, project: project, alert_rule: rule, :firing) }
    let!(:resolved_alert) { create(:alert, project: project, alert_rule: rule, :resolved) }

    it ".active returns pending and firing" do
      expect(Alert.active).to include(pending_alert, firing_alert)
      expect(Alert.active).not_to include(resolved_alert)
    end

    it ".firing returns only firing alerts" do
      expect(Alert.firing).to contain_exactly(firing_alert)
    end

    it ".pending returns only pending alerts" do
      expect(Alert.pending).to contain_exactly(pending_alert)
    end

    it ".resolved returns only resolved alerts" do
      expect(Alert.resolved).to contain_exactly(resolved_alert)
    end

    it ".unacknowledged excludes acknowledged alerts" do
      ack = create(:alert, project: project, alert_rule: rule, :acknowledged)
      expect(Alert.unacknowledged).not_to include(ack)
      expect(Alert.unacknowledged).to include(pending_alert)
    end

    it ".for_project scopes to the given project_id" do
      other_alert = create(:alert)
      expect(Alert.for_project(project.id)).to include(pending_alert)
      expect(Alert.for_project(project.id)).not_to include(other_alert)
    end
  end

  # ────────────────────────────────
  # #duration
  # ────────────────────────────────
  describe "#duration" do
    it "uses resolved_at as end when resolved" do
      alert = build(:alert, :resolved,
                    started_at: 2.hours.ago, resolved_at: 1.hour.ago)
      expect(alert.duration).to be_within(5).of(3600)
    end

    it "uses Time.current when still active" do
      Timecop.freeze do
        alert = build(:alert, started_at: 30.minutes.ago)
        expect(alert.duration).to be_within(5).of(1800)
      end
    end
  end

  # ────────────────────────────────
  # #duration_human
  # ────────────────────────────────
  describe "#duration_human" do
    it "returns a human-readable duration string" do
      alert = build(:alert, started_at: 1.hour.ago, resolved_at: Time.current)
      expect(alert.duration_human).to be_a(String)
      expect(alert.duration_human).not_to be_empty
    end
  end

  # ────────────────────────────────
  # #severity
  # ────────────────────────────────
  describe "#severity" do
    it "delegates to the alert_rule's severity" do
      rule  = build(:alert_rule, severity: "critical")
      alert = build(:alert, alert_rule: rule)
      expect(alert.severity).to eq("critical")
    end
  end

  # ────────────────────────────────
  # #fire!
  # ────────────────────────────────
  describe "#fire!" do
    let(:project) { create(:project) }
    let(:rule)    { create(:alert_rule, project: project, notify_channels: []) }
    let(:alert)   { create(:alert, project: project, alert_rule: rule, :pending) }

    before do
      allow(IncidentManager).to receive_message_chain(:new, :fire!)
      allow(NotificationJob).to receive(:perform_later)
    end

    it "transitions state to firing" do
      alert.fire!
      expect(alert.reload.state).to eq("firing")
    end

    it "sets last_fired_at" do
      Timecop.freeze do
        alert.fire!
        expect(alert.reload.last_fired_at).to be_within(1.second).of(Time.current)
      end
    end

    it "calls IncidentManager#fire!" do
      incident_manager = instance_double(IncidentManager)
      allow(IncidentManager).to receive(:new).with(alert).and_return(incident_manager)
      expect(incident_manager).to receive(:fire!)
      alert.fire!
    end
  end

  # ────────────────────────────────
  # #resolve!
  # ────────────────────────────────
  describe "#resolve!" do
    let(:project) { create(:project) }
    let(:rule)    { create(:alert_rule, project: project, notify_channels: []) }
    let(:alert)   { create(:alert, project: project, alert_rule: rule, :firing) }

    before do
      allow(IncidentManager).to receive_message_chain(:new, :resolve!)
      allow(NotificationJob).to receive(:perform_later)
    end

    it "transitions state to resolved" do
      alert.resolve!
      expect(alert.reload.state).to eq("resolved")
    end

    it "sets resolved_at" do
      Timecop.freeze do
        alert.resolve!
        expect(alert.reload.resolved_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  # ────────────────────────────────
  # #acknowledge!
  # ────────────────────────────────
  describe "#acknowledge!" do
    let(:alert) { create(:alert) }

    it "sets acknowledged=true and records who acknowledged" do
      Timecop.freeze do
        alert.acknowledge!(by: "ops@example.com", note: "Looking into it")
        alert.reload
        expect(alert.acknowledged).to be true
        expect(alert.acknowledged_by).to eq("ops@example.com")
        expect(alert.acknowledgment_note).to eq("Looking into it")
        expect(alert.acknowledged_at).to be_within(1.second).of(Time.current)
      end
    end
  end
end
