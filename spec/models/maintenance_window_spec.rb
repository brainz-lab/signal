require "rails_helper"

RSpec.describe MaintenanceWindow, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to belong_to(:project) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:starts_at) }
  it { is_expected.to validate_presence_of(:ends_at) }

  describe "#ends_after_starts" do
    it "is invalid when ends_at <= starts_at" do
      window = build(:maintenance_window, starts_at: 1.hour.from_now, ends_at: 30.minutes.from_now)
      expect(window).not_to be_valid
      expect(window.errors[:ends_at]).to include("must be after starts_at")
    end

    it "is invalid when ends_at equals starts_at" do
      t = 1.hour.from_now
      window = build(:maintenance_window, starts_at: t, ends_at: t)
      expect(window).not_to be_valid
    end

    it "is valid when ends_at is after starts_at" do
      window = build(:maintenance_window)
      expect(window).to be_valid
    end
  end

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let(:project) { create(:project) }

    let!(:active_future)  { create(:maintenance_window, project: project, active: true) }
    let!(:inactive)       { create(:maintenance_window, project: project, :inactive) }
    let!(:currently_on)   { create(:maintenance_window, project: project, :active_now) }

    it ".active returns windows with active=true" do
      expect(MaintenanceWindow.active).to include(active_future, currently_on)
      expect(MaintenanceWindow.active).not_to include(inactive)
    end

    it ".current returns windows where now is within the range" do
      expect(MaintenanceWindow.current).to include(currently_on)
      expect(MaintenanceWindow.current).not_to include(active_future)
    end

    it ".for_project scopes to the given project" do
      other = create(:maintenance_window)
      expect(MaintenanceWindow.for_project(project.id)).to include(active_future)
      expect(MaintenanceWindow.for_project(project.id)).not_to include(other)
    end
  end

  # ────────────────────────────────
  # #currently_active?
  # ────────────────────────────────
  describe "#currently_active?" do
    it "returns true when active and within the window" do
      window = build(:maintenance_window, :active_now, active: true)
      expect(window.currently_active?).to be true
    end

    it "returns false when active but window hasn't started" do
      window = build(:maintenance_window, active: true)
      expect(window.currently_active?).to be false
    end

    it "returns false when inactive even within the window" do
      window = build(:maintenance_window, :active_now, active: false)
      expect(window.currently_active?).to be false
    end
  end

  # ────────────────────────────────
  # #covers_rule?
  # ────────────────────────────────
  describe "#covers_rule?" do
    let(:rule_id) { SecureRandom.uuid }

    it "covers all rules when rule_ids is empty" do
      window = build(:maintenance_window, rule_ids: [])
      expect(window.covers_rule?(rule_id)).to be true
    end

    it "covers only specific rules when rule_ids is set" do
      window = build(:maintenance_window, rule_ids: [rule_id])
      expect(window.covers_rule?(rule_id)).to be true
      expect(window.covers_rule?(SecureRandom.uuid)).to be false
    end
  end
end
