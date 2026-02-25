require "rails_helper"

RSpec.describe "API V1 Alerts", type: :request do
  let(:project)  { create(:project) }
  let(:headers)  { auth_headers(project).merge("Content-Type" => "application/json") }
  let(:rule)     { create(:alert_rule, project: project) }

  before do
    allow(IncidentManager).to receive_message_chain(:new, :fire!)
    allow(IncidentManager).to receive_message_chain(:new, :resolve!)
    allow(NotificationJob).to receive(:perform_later)
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/alerts
  # ──────────────────────────────────────────────
  describe "GET /api/v1/alerts" do
    let!(:firing_alert)   { create(:alert, project: project, alert_rule: rule, :firing) }
    let!(:pending_alert)  { create(:alert, project: project, alert_rule: rule, :pending) }
    let!(:resolved_alert) { create(:alert, project: project, alert_rule: rule, :resolved) }

    it "returns all alerts for the project" do
      get "/api/v1/alerts", headers: headers
      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["alerts"].map { |a| a["id"] }
      expect(ids).to include(firing_alert.id, pending_alert.id, resolved_alert.id)
    end

    it "filters by state" do
      get "/api/v1/alerts", params: { state: "firing" }, headers: headers
      states = response.parsed_body["alerts"].map { |a| a["state"] }
      expect(states).to all(eq("firing"))
    end

    it "filters by severity" do
      critical_rule = create(:alert_rule, project: project, :critical)
      critical_alert = create(:alert, project: project, alert_rule: critical_rule, :firing)
      get "/api/v1/alerts", params: { severity: "critical" }, headers: headers
      ids = response.parsed_body["alerts"].map { |a| a["id"] }
      expect(ids).to include(critical_alert.id)
      expect(ids).not_to include(firing_alert.id)
    end

    it "filters unacknowledged alerts" do
      ack_alert = create(:alert, project: project, alert_rule: rule, :acknowledged)
      get "/api/v1/alerts", params: { unacknowledged: "true" }, headers: headers
      ids = response.parsed_body["alerts"].map { |a| a["id"] }
      expect(ids).not_to include(ack_alert.id)
    end

    it "does not return alerts from other projects" do
      other_alert = create(:alert)
      get "/api/v1/alerts", headers: headers
      ids = response.parsed_body["alerts"].map { |a| a["id"] }
      expect(ids).not_to include(other_alert.id)
    end

    it "returns 401 without authentication" do
      get "/api/v1/alerts"
      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts X-API-Key header" do
      get "/api/v1/alerts",
          headers: { "X-API-Key" => project.settings["api_key"] }
      expect(response).to have_http_status(:ok)
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/alerts/:id
  # ──────────────────────────────────────────────
  describe "GET /api/v1/alerts/:id" do
    let!(:alert) { create(:alert, project: project, alert_rule: rule, :firing) }

    it "returns the alert with rule info" do
      get "/api/v1/alerts/#{alert.id}", headers: headers
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["id"]).to eq(alert.id)
      expect(body["state"]).to eq("firing")
      expect(body["rule"]["name"]).to eq(rule.name)
    end

    it "returns 404 for unknown alert" do
      get "/api/v1/alerts/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "does not expose alerts from other projects" do
      other_alert = create(:alert)
      get "/api/v1/alerts/#{other_alert.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/alerts/:id/acknowledge
  # ──────────────────────────────────────────────
  describe "POST /api/v1/alerts/:id/acknowledge" do
    let!(:alert) { create(:alert, project: project, alert_rule: rule, :firing) }

    it "acknowledges the alert and returns updated state" do
      post "/api/v1/alerts/#{alert.id}/acknowledge",
           params: { by: "ops@example.com", note: "Investigating" }.to_json,
           headers: headers
      expect(response).to have_http_status(:ok)
      expect(alert.reload.acknowledged).to be true
      expect(alert.acknowledged_by).to eq("ops@example.com")
    end

    it "returns 404 for unknown alert" do
      post "/api/v1/alerts/#{SecureRandom.uuid}/acknowledge",
           params: {}.to_json, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
