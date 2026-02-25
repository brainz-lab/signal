require "rails_helper"

RSpec.describe AlertHistory, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:alert_rule) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:timestamp) }
  it { is_expected.to validate_presence_of(:state) }
  it { is_expected.to validate_inclusion_of(:state).in_array(%w[ok pending firing]) }

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let(:project) { create(:project) }
    let(:rule)    { create(:alert_rule, project: project) }

    let!(:old_ok)     { create(:alert_history, project: project, alert_rule: rule,
                                state: "ok", timestamp: 2.hours.ago) }
    let!(:recent_firing) { create(:alert_history, project: project, alert_rule: rule,
                                  :firing, timestamp: 5.minutes.ago) }

    it ".recent returns entries ordered by timestamp descending" do
      expect(AlertHistory.recent.first).to eq(recent_firing)
      expect(AlertHistory.recent.last).to eq(old_ok)
    end

    it ".for_project scopes to the given project" do
      other_project = create(:project)
      other_rule    = create(:alert_rule, project: other_project)
      other_history = create(:alert_history, project: other_project, alert_rule: other_rule)

      expect(AlertHistory.for_project(project.id)).to include(old_ok, recent_firing)
      expect(AlertHistory.for_project(project.id)).not_to include(other_history)
    end
  end

  # ────────────────────────────────
  # Defaults
  # ────────────────────────────────
  describe "defaults" do
    it "initializes labels as empty hash" do
      history = create(:alert_history)
      expect(history.labels).to eq({})
    end
  end

  # ────────────────────────────────
  # Data integrity
  # ────────────────────────────────
  describe "value storage" do
    it "stores nil value for ok state" do
      history = create(:alert_history, :ok)
      expect(history.value).to be_nil
    end

    it "stores numeric value for firing state" do
      history = create(:alert_history, :firing)
      expect(history.value).to eq(7.2)
    end
  end
end
