require "rails_helper"

RSpec.describe Incident, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:alerts).dependent(:nullify) }
  it { is_expected.to have_many(:notifications).dependent(:destroy) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_inclusion_of(:status).in_array(%w[triggered acknowledged resolved]) }
  it { is_expected.to validate_inclusion_of(:severity).in_array(%w[info warning critical]) }

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let!(:triggered)    { create(:incident, status: "triggered") }
    let!(:acknowledged) { create(:incident, :acknowledged) }
    let!(:resolved)     { create(:incident, :resolved) }

    it ".open returns triggered and acknowledged" do
      expect(Incident.open).to include(triggered, acknowledged)
      expect(Incident.open).not_to include(resolved)
    end

    it ".resolved returns only resolved incidents" do
      expect(Incident.resolved).to contain_exactly(resolved)
    end

    it ".by_severity filters by severity" do
      critical = create(:incident, :critical)
      expect(Incident.by_severity("critical")).to include(critical)
      expect(Incident.by_severity("critical")).not_to include(triggered)
    end

    it ".for_project scopes to the given project" do
      project = create(:project)
      scoped  = create(:incident, project: project)
      expect(Incident.for_project(project.id)).to include(scoped)
      expect(Incident.for_project(project.id)).not_to include(triggered)
    end
  end

  # ────────────────────────────────
  # #acknowledge!
  # ────────────────────────────────
  describe "#acknowledge!" do
    let(:incident) { create(:incident) }

    it "sets status to acknowledged and records who did it" do
      Timecop.freeze do
        incident.acknowledge!(by: "ops@example.com")
        incident.reload
        expect(incident.status).to eq("acknowledged")
        expect(incident.acknowledged_by).to eq("ops@example.com")
        expect(incident.acknowledged_at).to be_within(1.second).of(Time.current)
      end
    end

    it "does nothing if already resolved" do
      resolved = create(:incident, :resolved)
      resolved.acknowledge!(by: "ops@example.com")
      expect(resolved.reload.status).to eq("resolved")
    end

    it "adds a timeline event" do
      incident.acknowledge!(by: "ops@example.com")
      expect(incident.reload.timeline.last["type"]).to eq("acknowledged")
    end
  end

  # ────────────────────────────────
  # #resolve!
  # ────────────────────────────────
  describe "#resolve!" do
    let(:incident) { create(:incident) }

    it "sets status to resolved with timestamp and note" do
      Timecop.freeze do
        incident.resolve!(by: "alice@example.com", note: "Fixed by rollback")
        incident.reload
        expect(incident.status).to eq("resolved")
        expect(incident.resolved_by).to eq("alice@example.com")
        expect(incident.resolution_note).to eq("Fixed by rollback")
        expect(incident.resolved_at).to be_within(1.second).of(Time.current)
      end
    end

    it "adds a resolved event to the timeline" do
      incident.resolve!(by: "alice@example.com")
      event = incident.reload.timeline.last
      expect(event["type"]).to eq("resolved")
      expect(event["by"]).to eq("alice@example.com")
    end
  end

  # ────────────────────────────────
  # #add_timeline_event
  # ────────────────────────────────
  describe "#add_timeline_event" do
    let(:incident) { create(:incident) }

    it "appends an event to the timeline" do
      expect {
        incident.add_timeline_event(type: "comment", message: "Investigating", by: "bob@example.com")
      }.to change { incident.reload.timeline.length }.by(1)

      event = incident.timeline.last
      expect(event["type"]).to eq("comment")
      expect(event["message"]).to eq("Investigating")
      expect(event["by"]).to eq("bob@example.com")
      expect(event["at"]).to be_present
    end
  end

  # ────────────────────────────────
  # #duration
  # ────────────────────────────────
  describe "#duration" do
    it "returns elapsed seconds since triggered_at" do
      incident = build(:incident, triggered_at: 2.hours.ago, resolved_at: nil)
      expect(incident.duration).to be_within(5).of(7200)
    end

    it "uses resolved_at when resolved" do
      incident = build(:incident, :resolved,
                       triggered_at: 3.hours.ago, resolved_at: 1.hour.ago)
      expect(incident.duration).to be_within(5).of(7200)
    end
  end
end
