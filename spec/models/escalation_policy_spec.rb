require "rails_helper"

RSpec.describe EscalationPolicy, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:alert_rules).dependent(:nullify) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:slug) }

  describe "slug uniqueness" do
    it "is scoped to project" do
      project = create(:project)
      create(:escalation_policy, project: project, slug: "critical-escalation")
      dup = build(:escalation_policy, project: project, slug: "critical-escalation")
      expect(dup).not_to be_valid
    end

    it "allows same slug in different projects" do
      create(:escalation_policy, slug: "critical-escalation")
      policy = build(:escalation_policy, slug: "critical-escalation")
      expect(policy).to be_valid
    end
  end

  # ────────────────────────────────
  # Callbacks
  # ────────────────────────────────
  describe "before_validation :generate_slug" do
    it "generates slug from name on create" do
      policy = create(:escalation_policy, name: "Critical Alerts", slug: nil)
      expect(policy.slug).to eq("critical-alerts")
    end
  end

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let(:project) { create(:project) }
    let!(:enabled_policy)  { create(:escalation_policy, project: project, enabled: true) }
    let!(:disabled_policy) { create(:escalation_policy, project: project, enabled: false) }

    it ".enabled returns only enabled policies" do
      expect(EscalationPolicy.enabled).to include(enabled_policy)
      expect(EscalationPolicy.enabled).not_to include(disabled_policy)
    end

    it ".for_project scopes to the given project" do
      other = create(:escalation_policy)
      expect(EscalationPolicy.for_project(project.id)).to include(enabled_policy)
      expect(EscalationPolicy.for_project(project.id)).not_to include(other)
    end
  end

  # ────────────────────────────────
  # Defaults
  # ────────────────────────────────
  describe "defaults" do
    it "initializes with enabled=true and empty steps" do
      policy = create(:escalation_policy)
      expect(policy.enabled).to be true
      expect(policy.steps).to eq([])
      expect(policy.repeat).to be false
    end
  end
end
