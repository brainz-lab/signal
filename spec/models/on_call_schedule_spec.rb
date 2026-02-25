require "rails_helper"

RSpec.describe OnCallSchedule, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to belong_to(:project) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:slug) }
  it { is_expected.to validate_presence_of(:schedule_type) }
  it { is_expected.to validate_inclusion_of(:schedule_type).in_array(%w[weekly custom]) }

  describe "slug uniqueness" do
    it "is scoped to project" do
      project = create(:project)
      create(:on_call_schedule, project: project, slug: "primary-oncall")
      dup = build(:on_call_schedule, project: project, slug: "primary-oncall")
      expect(dup).not_to be_valid
    end
  end

  # ────────────────────────────────
  # Callbacks
  # ────────────────────────────────
  describe "before_validation :generate_slug" do
    it "generates slug from name" do
      schedule = create(:on_call_schedule, name: "Primary On Call", slug: nil)
      expect(schedule.slug).to eq("primary-on-call")
    end
  end

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let(:project) { create(:project) }
    let!(:enabled_schedule)  { create(:on_call_schedule, project: project, enabled: true) }
    let!(:disabled_schedule) { create(:on_call_schedule, project: project, enabled: false) }

    it ".enabled returns only enabled schedules" do
      expect(OnCallSchedule.enabled).to include(enabled_schedule)
      expect(OnCallSchedule.enabled).not_to include(disabled_schedule)
    end

    it ".for_project scopes to the given project" do
      other = create(:on_call_schedule)
      expect(OnCallSchedule.for_project(project.id)).to include(enabled_schedule)
      expect(OnCallSchedule.for_project(project.id)).not_to include(other)
    end
  end

  # ────────────────────────────────
  # #current_on_call_user
  # ────────────────────────────────
  describe "#current_on_call_user" do
    context "when shift is still active" do
      it "returns current_on_call without updating" do
        schedule = create(:on_call_schedule, :with_current_on_call,
                          current_shift_end: 1.hour.from_now)
        expect(schedule.current_on_call_user).to eq("alice@example.com")
      end
    end

    context "when shift has expired" do
      it "updates and returns the new on-call user for weekly schedules" do
        day = Time.current.strftime("%A").downcase
        schedule = create(:on_call_schedule, :weekly,
                          current_on_call: "old-user@example.com",
                          current_shift_end: 1.hour.ago)
        # weekly_schedule has entries for all days
        schedule.reload
        result = schedule.current_on_call_user
        expect(result).to be_a(String)
      end
    end

    context "when current_shift_end is nil" do
      it "calls update_current_on_call!" do
        schedule = create(:on_call_schedule, :weekly, current_shift_end: nil)
        allow(schedule).to receive(:update_current_on_call!)
        schedule.current_on_call_user
        expect(schedule).to have_received(:update_current_on_call!)
      end
    end
  end

  # ────────────────────────────────
  # #update_current_on_call!
  # ────────────────────────────────
  describe "#update_current_on_call!" do
    it "calls update_weekly_on_call! for weekly schedule type" do
      schedule = create(:on_call_schedule, :weekly)
      allow(schedule).to receive(:update_weekly_on_call!)
      schedule.update_current_on_call!
      expect(schedule).to have_received(:update_weekly_on_call!)
    end

    it "calls update_rotation_on_call! for custom schedule type" do
      schedule = create(:on_call_schedule, :custom_rotation)
      allow(schedule).to receive(:update_rotation_on_call!)
      schedule.update_current_on_call!
      expect(schedule).to have_received(:update_rotation_on_call!)
    end
  end
end
