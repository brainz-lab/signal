require "rails_helper"

RSpec.describe "API V1 Incidents", type: :request do
  let(:project) { create(:project) }
  let(:headers) { auth_headers(project).merge("Content-Type" => "application/json") }

  # ──────────────────────────────────────────────
  # GET /api/v1/incidents
  # ──────────────────────────────────────────────
  describe "GET /api/v1/incidents" do
    let!(:triggered)    { create(:incident, project: project) }
    let!(:acknowledged) { create(:incident, project: project, :acknowledged) }
    let!(:resolved)     { create(:incident, project: project, :resolved) }

    it "returns all incidents for the project" do
      get "/api/v1/incidents", headers: headers
      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["incidents"].map { |i| i["id"] }
      expect(ids).to include(triggered.id, acknowledged.id, resolved.id)
    end

    it "filters by status" do
      get "/api/v1/incidents", params: { status: "triggered" }, headers: headers
      statuses = response.parsed_body["incidents"].map { |i| i["status"] }
      expect(statuses).to all(eq("triggered"))
    end

    it "filters by severity" do
      critical = create(:incident, project: project, :critical)
      get "/api/v1/incidents", params: { severity: "critical" }, headers: headers
      ids = response.parsed_body["incidents"].map { |i| i["id"] }
      expect(ids).to include(critical.id)
      expect(ids).not_to include(triggered.id)
    end

    it "does not return incidents from other projects" do
      other = create(:incident)
      get "/api/v1/incidents", headers: headers
      ids = response.parsed_body["incidents"].map { |i| i["id"] }
      expect(ids).not_to include(other.id)
    end

    it "returns 401 without authentication" do
      get "/api/v1/incidents"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/incidents/:id
  # ──────────────────────────────────────────────
  describe "GET /api/v1/incidents/:id" do
    let!(:incident) { create(:incident, project: project, :with_timeline) }

    it "returns the incident with timeline" do
      get "/api/v1/incidents/#{incident.id}", headers: headers
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["id"]).to eq(incident.id)
      expect(body["title"]).to eq(incident.title)
      expect(body["timeline"]).to be_an(Array)
    end

    it "returns 404 for unknown incident" do
      get "/api/v1/incidents/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "does not expose incidents from other projects" do
      other = create(:incident)
      get "/api/v1/incidents/#{other.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/incidents/:id/acknowledge
  # ──────────────────────────────────────────────
  describe "POST /api/v1/incidents/:id/acknowledge" do
    let!(:incident) { create(:incident, project: project) }

    it "acknowledges the incident" do
      post "/api/v1/incidents/#{incident.id}/acknowledge",
           params: { by: "ops@example.com" }.to_json,
           headers: headers
      expect(response).to have_http_status(:ok)
      incident.reload
      expect(incident.status).to eq("acknowledged")
      expect(incident.acknowledged_by).to eq("ops@example.com")
    end

    it "returns 404 for unknown incident" do
      post "/api/v1/incidents/#{SecureRandom.uuid}/acknowledge",
           params: {}.to_json, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/incidents/:id/resolve
  # ──────────────────────────────────────────────
  describe "POST /api/v1/incidents/:id/resolve" do
    let!(:incident) { create(:incident, project: project) }

    it "resolves the incident with a note" do
      post "/api/v1/incidents/#{incident.id}/resolve",
           params: { by: "alice@example.com", note: "Fixed by rollback" }.to_json,
           headers: headers
      expect(response).to have_http_status(:ok)
      incident.reload
      expect(incident.status).to eq("resolved")
      expect(incident.resolved_by).to eq("alice@example.com")
      expect(incident.resolution_note).to eq("Fixed by rollback")
    end
  end
end
