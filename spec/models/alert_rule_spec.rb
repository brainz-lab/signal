require "rails_helper"

RSpec.describe AlertRule, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:escalation_policy).optional }
  it { is_expected.to have_many(:alerts).dependent(:destroy) }
  it { is_expected.to have_many(:alert_histories).dependent(:destroy) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:slug) }
  it { is_expected.to validate_presence_of(:source) }
  it { is_expected.to validate_presence_of(:rule_type) }
  it { is_expected.to validate_inclusion_of(:source).in_array(%w[flux pulse reflex recall]) }
  it { is_expected.to validate_inclusion_of(:rule_type).in_array(%w[threshold anomaly absence composite]) }
  it { is_expected.to validate_inclusion_of(:severity).in_array(%w[info warning critical]) }

  describe "slug uniqueness" do
    let(:project) { create(:project) }

    it "is scoped to project" do
      create(:alert_rule, project: project, name: "High Error Rate", slug: "high-error-rate")
      duplicate = build(:alert_rule, project: project, name: "Other", slug: "high-error-rate")
      expect(duplicate).not_to be_valid
    end

    it "allows the same slug in different projects" do
      create(:alert_rule, slug: "high-error-rate")
      rule = build(:alert_rule, slug: "high-error-rate")
      expect(rule).to be_valid
    end
  end

  # ────────────────────────────────
  # Callbacks
  # ────────────────────────────────
  describe "before_validation :generate_slug" do
    it "generates slug from name on create" do
      rule = create(:alert_rule, name: "High Error Rate", slug: nil)
      expect(rule.slug).to eq("high-error-rate")
    end

    it "does not overwrite an existing slug" do
      rule = create(:alert_rule, name: "High Error Rate", slug: "custom-slug")
      expect(rule.slug).to eq("custom-slug")
    end
  end

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let(:project) { create(:project) }
    let!(:enabled_rule)  { create(:alert_rule, project: project, enabled: true, muted: false) }
    let!(:disabled_rule) { create(:alert_rule, project: project, :disabled) }
    let!(:muted_rule)    { create(:alert_rule, project: project, enabled: true, :muted) }

    it ".enabled returns only enabled rules" do
      expect(AlertRule.enabled).to include(enabled_rule, muted_rule)
      expect(AlertRule.enabled).not_to include(disabled_rule)
    end

    it ".active returns enabled and non-muted rules" do
      expect(AlertRule.active).to include(enabled_rule)
      expect(AlertRule.active).not_to include(disabled_rule, muted_rule)
    end

    it ".by_source filters by source" do
      pulse_rule = create(:alert_rule, project: project, source: "pulse")
      flux_rule  = create(:alert_rule, project: project, source: "flux")
      expect(AlertRule.by_source("pulse")).to include(pulse_rule)
      expect(AlertRule.by_source("pulse")).not_to include(flux_rule)
    end

    it ".for_project scopes to the given project" do
      other_rule = create(:alert_rule)
      expect(AlertRule.for_project(project.id)).to include(enabled_rule)
      expect(AlertRule.for_project(project.id)).not_to include(other_rule)
    end
  end

  # ────────────────────────────────
  # Constants
  # ────────────────────────────────
  describe "OPERATORS" do
    it "maps string keys to operator symbols" do
      expect(AlertRule::OPERATORS["gt"]).to eq(">")
      expect(AlertRule::OPERATORS["lte"]).to eq("<=")
      expect(AlertRule::OPERATORS["eq"]).to eq("==")
      expect(AlertRule::OPERATORS["neq"]).to eq("!=")
    end
  end

  # ────────────────────────────────
  # muted?
  # ────────────────────────────────
  describe "#muted?" do
    it "returns false when muted is false" do
      rule = build(:alert_rule, muted: false)
      expect(rule.muted?).to be false
    end

    it "returns true when muted with no expiry" do
      rule = build(:alert_rule, :muted, muted_until: nil)
      expect(rule.muted?).to be true
    end

    it "returns true when muted_until is in the future" do
      rule = build(:alert_rule, :muted_temporarily)
      expect(rule.muted?).to be true
    end

    it "returns false when muted_until has passed" do
      rule = build(:alert_rule, muted: true, muted_until: 1.minute.ago)
      expect(rule.muted?).to be false
    end
  end

  # ────────────────────────────────
  # mute! / unmute!
  # ────────────────────────────────
  describe "#mute! and #unmute!" do
    let(:rule) { create(:alert_rule) }

    it "mute! sets muted=true and optional reason/expiry" do
      rule.mute!(until_time: 2.hours.from_now, reason: "Deploy")
      expect(rule.reload.muted).to be true
      expect(rule.muted_reason).to eq("Deploy")
      expect(rule.muted_until).to be > Time.current
    end

    it "unmute! clears muted state" do
      rule.mute!
      rule.unmute!
      expect(rule.reload.muted).to be false
      expect(rule.muted_until).to be_nil
    end
  end

  # ────────────────────────────────
  # condition_description
  # ────────────────────────────────
  describe "#condition_description" do
    it "describes threshold rules" do
      rule = build(:alert_rule, rule_type: "threshold", aggregation: "avg",
                                source_name: "error_rate", operator: "gt",
                                threshold: 5.0, window: "5m")
      expect(rule.condition_description).to include("avg", "error_rate", ">", "5.0", "5m")
    end

    it "describes anomaly rules" do
      rule = build(:alert_rule, :anomaly, source_name: "response_time")
      expect(rule.condition_description).to include("Anomaly", "response_time")
    end

    it "describes absence rules" do
      rule = build(:alert_rule, :absence, source_name: "heartbeat")
      expect(rule.condition_description).to include("No data", "heartbeat")
    end

    it "describes composite rules" do
      rule = build(:alert_rule, :composite)
      expect(rule.condition_description).to include("Composite")
    end
  end

  # ────────────────────────────────
  # notification_channels
  # ────────────────────────────────
  describe "#notification_channels" do
    let(:project) { create(:project) }
    let(:channel) { create(:notification_channel, project: project) }
    let(:rule) { create(:alert_rule, project: project, notify_channels: [channel.id]) }

    it "returns channels matching notify_channels IDs" do
      expect(rule.notification_channels).to include(channel)
    end

    it "returns empty when notify_channels is empty" do
      rule.update!(notify_channels: [])
      expect(rule.notification_channels).to be_empty
    end
  end
end
