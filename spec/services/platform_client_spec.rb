require "rails_helper"

RSpec.describe PlatformClient do
  let(:platform_url)   { ENV.fetch("BRAINZLAB_PLATFORM_URL", "https://platform.brainzlab.ai") }
  let(:validate_url)   { "#{platform_url}/api/v1/keys/validate" }
  let(:api_key)        { "sk_live_test_key_abc123" }
  let(:project_uuid)   { SecureRandom.uuid }

  let(:valid_response) do
    {
      valid: true,
      project_id: project_uuid,
      project_slug: "my-app",
      organization_id: SecureRandom.uuid,
      organization_slug: "my-org",
      environment: "production",
      plan: "pro",
      scopes: ["read", "write"],
      features: {}
    }.to_json
  end

  before do
    Rails.cache.clear
  end

  # ────────────────────────────────
  # ValidationResult
  # ────────────────────────────────
  describe "ValidationResult" do
    it "returns valid? true for valid results" do
      result = described_class::ValidationResult.new(valid: true, project_id: project_uuid)
      expect(result.valid?).to be true
    end

    it "returns valid? false for invalid results" do
      result = described_class::ValidationResult.new(valid: false, error: "Unauthorized")
      expect(result.valid?).to be false
      expect(result.error).to eq("Unauthorized")
    end

    it "defaults scopes and features to empty collections" do
      result = described_class::ValidationResult.new(valid: true)
      expect(result.scopes).to eq([])
      expect(result.features).to eq({})
    end
  end

  # ────────────────────────────────
  # .validate_key
  # ────────────────────────────────
  describe ".validate_key" do
    context "with a valid key" do
      before do
        stub_request(:post, validate_url)
          .to_return(status: 200, body: valid_response,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns a valid ValidationResult" do
        result = described_class.validate_key(api_key)
        expect(result.valid?).to be true
        expect(result.project_id).to eq(project_uuid)
        expect(result.environment).to eq("production")
      end

      it "caches the result on repeated calls" do
        described_class.validate_key(api_key)
        described_class.validate_key(api_key)
        expect(WebMock).to have_requested(:post, validate_url).once
      end
    end

    context "with an invalid key" do
      before do
        stub_request(:post, validate_url)
          .to_return(status: 401, body: '{"error":"Invalid key"}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns an invalid ValidationResult" do
        result = described_class.validate_key("bad_key")
        expect(result.valid?).to be false
      end
    end

    context "with a blank key" do
      it "returns invalid without making an HTTP request" do
        result = described_class.validate_key("")
        expect(result.valid?).to be false
        expect(WebMock).not_to have_requested(:post, validate_url)
      end
    end

    context "when Platform times out" do
      before do
        stub_request(:post, validate_url).to_timeout
      end

      it "returns an invalid result with timeout error" do
        result = described_class.validate_key(api_key)
        expect(result.valid?).to be false
        expect(result.error).to include("timeout")
      end
    end
  end

  # ────────────────────────────────
  # .find_or_create_project
  # ────────────────────────────────
  describe ".find_or_create_project" do
    let(:validation_result) do
      described_class::ValidationResult.new(
        valid: true,
        project_id: project_uuid,
        project_slug: "my-app",
        environment: "production"
      )
    end

    context "when no local project exists" do
      it "creates a new project" do
        expect {
          described_class.find_or_create_project(validation_result, api_key)
        }.to change(Project, :count).by(1)
      end

      it "assigns the platform_project_id and api_key" do
        project = described_class.find_or_create_project(validation_result, api_key)
        expect(project.platform_project_id.to_s).to eq(project_uuid)
        expect(project.settings["api_key"]).to eq(api_key)
      end
    end

    context "when project already exists" do
      let!(:existing_project) do
        create(:project, platform_project_id: project_uuid,
               settings: { "api_key" => api_key, "ingest_key" => "sig_ingest_existing" })
      end

      it "returns the existing project" do
        project = described_class.find_or_create_project(validation_result, api_key)
        expect(project.id).to eq(existing_project.id)
        expect(Project.count).to eq(1)
      end

      it "updates the api_key if it changed (key regeneration)" do
        new_key = "sk_live_new_regenerated_key"
        described_class.find_or_create_project(validation_result, new_key)
        expect(existing_project.reload.settings["api_key"]).to eq(new_key)
      end
    end

    context "with an invalid validation result" do
      it "returns nil" do
        invalid_result = described_class::ValidationResult.new(valid: false)
        expect(described_class.find_or_create_project(invalid_result, api_key)).to be_nil
      end
    end
  end
end
