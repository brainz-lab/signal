require "rails_helper"

RSpec.describe Project, type: :model do
  # ────────────────────────────────
  # Associations
  # ────────────────────────────────
  it { is_expected.to have_many(:alerts).dependent(:destroy) }
  it { is_expected.to have_many(:alert_rules).dependent(:destroy) }
  it { is_expected.to have_many(:incidents).dependent(:destroy) }
  it { is_expected.to have_many(:notification_channels).dependent(:destroy) }
  it { is_expected.to have_many(:escalation_policies).dependent(:destroy) }
  it { is_expected.to have_many(:on_call_schedules).dependent(:destroy) }
  it { is_expected.to have_many(:maintenance_windows).dependent(:destroy) }

  # ────────────────────────────────
  # Validations
  # ────────────────────────────────
  it { is_expected.to validate_presence_of(:platform_project_id) }
  it { is_expected.to validate_uniqueness_of(:platform_project_id) }

  # ────────────────────────────────
  # Callbacks — generate_keys
  # ────────────────────────────────
  describe "before_create :generate_keys" do
    it "generates sig_api_ and sig_ingest_ keys on create" do
      project = Project.new(platform_project_id: SecureRandom.uuid, settings: {})
      project.save!

      expect(project.settings["api_key"]).to start_with("sig_api_")
      expect(project.settings["ingest_key"]).to start_with("sig_ingest_")
    end

    it "does not overwrite existing keys" do
      existing = { "api_key" => "sig_api_keep", "ingest_key" => "sig_ingest_keep" }
      project = Project.new(platform_project_id: SecureRandom.uuid, settings: existing)
      project.save!

      expect(project.settings["api_key"]).to eq("sig_api_keep")
      expect(project.settings["ingest_key"]).to eq("sig_ingest_keep")
    end
  end

  # ────────────────────────────────
  # Scopes
  # ────────────────────────────────
  describe "scopes" do
    let!(:active_project)   { create(:project) }
    let!(:archived_project) { create(:project, :archived) }

    it ".active returns non-archived projects" do
      expect(Project.active).to include(active_project)
      expect(Project.active).not_to include(archived_project)
    end

    it ".archived returns only archived projects" do
      expect(Project.archived).to include(archived_project)
      expect(Project.archived).not_to include(active_project)
    end
  end

  # ────────────────────────────────
  # Class methods
  # ────────────────────────────────
  describe ".find_or_create_for_platform!" do
    let(:uid) { SecureRandom.uuid }

    it "creates a new project when none exists" do
      expect {
        Project.find_or_create_for_platform!(platform_project_id: uid, name: "My App")
      }.to change(Project, :count).by(1)
    end

    it "returns the existing project on repeat call" do
      Project.find_or_create_for_platform!(platform_project_id: uid, name: "My App")
      expect {
        Project.find_or_create_for_platform!(platform_project_id: uid, name: "My App")
      }.not_to change(Project, :count)
    end

    it "assigns name and environment on creation" do
      project = Project.find_or_create_for_platform!(
        platform_project_id: uid, name: "Test", environment: "staging"
      )
      expect(project.name).to eq("Test")
      expect(project.environment).to eq("staging")
    end
  end

  # ────────────────────────────────
  # Instance methods
  # ────────────────────────────────
  describe "#api_key" do
    it "returns the api_key from settings" do
      project = create(:project)
      expect(project.api_key).to start_with("sig_api_")
    end
  end

  describe "#ingest_key" do
    it "returns the ingest_key from settings" do
      project = create(:project)
      expect(project.ingest_key).to start_with("sig_ingest_")
    end
  end

  describe "#origin_allowed?" do
    let(:project) { create(:project) }

    it "allows any origin when allowed_origins is empty" do
      expect(project.origin_allowed?("https://any.example.com")).to be true
    end

    it "restricts to listed origins when set" do
      project.settings["allowed_origins"] = ["https://app.example.com"]
      project.save!
      expect(project.origin_allowed?("https://app.example.com")).to be true
      expect(project.origin_allowed?("https://evil.example.com")).to be false
    end
  end
end
