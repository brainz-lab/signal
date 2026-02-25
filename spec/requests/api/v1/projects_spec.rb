require "rails_helper"

RSpec.describe "API V1 Projects", type: :request do
  let(:master_key) { "test_master_key_signal" }
  let(:headers) { master_key_headers(master_key).merge("Content-Type" => "application/json") }

  before { stub_const("ENV", ENV.to_h.merge("SIGNAL_MASTER_KEY" => master_key)) }

  # ──────────────────────────────────────────────
  # POST /api/v1/projects/provision
  # ──────────────────────────────────────────────
  describe "POST /api/v1/projects/provision" do
    let(:platform_id) { SecureRandom.uuid }

    context "with a platform_project_id" do
      let(:payload) { { platform_project_id: platform_id, name: "My App", environment: "production" } }

      it "creates a new project and returns 200" do
        expect {
          post "/api/v1/projects/provision", params: payload.to_json, headers: headers
        }.to change(Project, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it "returns api_key and ingest_key prefixed with sig_" do
        post "/api/v1/projects/provision", params: payload.to_json, headers: headers
        body = response.parsed_body
        expect(body["api_key"]).to start_with("sig_api_")
        expect(body["ingest_key"]).to start_with("sig_ingest_")
        expect(body["platform_project_id"]).to eq(platform_id)
      end

      it "is idempotent — does not duplicate on repeated calls" do
        post "/api/v1/projects/provision", params: payload.to_json, headers: headers
        expect {
          post "/api/v1/projects/provision", params: payload.to_json, headers: headers
        }.not_to change(Project, :count)
      end
    end

    context "with a name only (standalone mode)" do
      it "creates a project with a generated platform_project_id" do
        post "/api/v1/projects/provision",
             params: { name: "Standalone App" }.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["platform_project_id"]).to be_present
        expect(body["api_key"]).to start_with("sig_api_")
      end
    end

    context "without platform_project_id or name" do
      it "returns 400 bad_request" do
        post "/api/v1/projects/provision", params: {}.to_json, headers: headers
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "without master key" do
      it "returns 401" do
        post "/api/v1/projects/provision",
             params: { platform_project_id: SecureRandom.uuid }.to_json,
             headers: { "Content-Type" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with incorrect master key" do
      it "returns 401" do
        post "/api/v1/projects/provision",
             params: { platform_project_id: SecureRandom.uuid }.to_json,
             headers: master_key_headers("wrong_key").merge("Content-Type" => "application/json")
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/projects/lookup
  # ──────────────────────────────────────────────
  describe "GET /api/v1/projects/lookup" do
    let(:platform_id) { SecureRandom.uuid }
    let!(:project) do
      create(:project, name: "Lookup App", platform_project_id: platform_id,
             settings: { "api_key" => "sig_api_abc", "ingest_key" => "sig_ingest_abc",
                         "allowed_origins" => [] })
    end

    it "finds a project by platform_project_id" do
      get "/api/v1/projects/lookup",
          params: { platform_project_id: platform_id }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq("Lookup App")
    end

    it "finds a project by name" do
      get "/api/v1/projects/lookup",
          params: { name: "Lookup App" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["platform_project_id"]).to eq(platform_id)
    end

    it "returns 404 when not found" do
      get "/api/v1/projects/lookup",
          params: { platform_project_id: SecureRandom.uuid }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without master key" do
      get "/api/v1/projects/lookup",
          params: { platform_project_id: platform_id }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
