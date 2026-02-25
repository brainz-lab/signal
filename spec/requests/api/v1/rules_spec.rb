require "rails_helper"

RSpec.describe "API V1 Rules", type: :request do
  let(:project) { create(:project) }
  let(:headers) { auth_headers(project).merge("Content-Type" => "application/json") }

  before do
    allow(RuleEvaluator).to receive_message_chain(:new, :evaluate).and_return(
      { state: "ok", value: 2.0, fingerprint: "fp-test", labels: {} }
    )
    allow(AlertManager).to receive_message_chain(:new, :process)
    allow(AlertHistory).to receive(:create!)
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/rules
  # ──────────────────────────────────────────────
  describe "GET /api/v1/rules" do
    let!(:pulse_rule) { create(:alert_rule, project: project, source: "pulse") }
    let!(:flux_rule)  { create(:alert_rule, project: project, source: "flux") }

    it "returns all rules for the project" do
      get "/api/v1/rules", headers: headers
      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["rules"].map { |r| r["id"] }
      expect(ids).to include(pulse_rule.id, flux_rule.id)
    end

    it "filters by source" do
      get "/api/v1/rules", params: { source: "pulse" }, headers: headers
      sources = response.parsed_body["rules"].map { |r| r["source"] }
      expect(sources).to all(eq("pulse"))
    end

    it "filters enabled rules" do
      disabled = create(:alert_rule, project: project, :disabled)
      get "/api/v1/rules", params: { enabled: "true" }, headers: headers
      ids = response.parsed_body["rules"].map { |r| r["id"] }
      expect(ids).not_to include(disabled.id)
    end

    it "does not return rules from other projects" do
      other_rule = create(:alert_rule)
      get "/api/v1/rules", headers: headers
      ids = response.parsed_body["rules"].map { |r| r["id"] }
      expect(ids).not_to include(other_rule.id)
    end

    it "returns 401 without authentication" do
      get "/api/v1/rules"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/rules/:id
  # ──────────────────────────────────────────────
  describe "GET /api/v1/rules/:id" do
    let!(:rule) { create(:alert_rule, project: project) }

    it "returns the rule with full details" do
      get "/api/v1/rules/#{rule.id}", headers: headers
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["id"]).to eq(rule.id)
      expect(body["name"]).to eq(rule.name)
      expect(body).to have_key("threshold")
    end

    it "returns 404 for unknown rule" do
      get "/api/v1/rules/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/rules
  # ──────────────────────────────────────────────
  describe "POST /api/v1/rules" do
    let(:payload) do
      {
        rule: {
          name: "High Error Rate",
          source: "pulse",
          source_name: "error_rate",
          rule_type: "threshold",
          operator: "gt",
          threshold: 5.0,
          aggregation: "avg",
          window: "5m",
          severity: "critical"
        }
      }
    end

    it "creates a new rule and returns 201" do
      expect {
        post "/api/v1/rules", params: payload.to_json, headers: headers
      }.to change(AlertRule, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("High Error Rate")
    end

    it "auto-generates slug from name" do
      post "/api/v1/rules", params: payload.to_json, headers: headers
      expect(response.parsed_body["slug"]).to eq("high-error-rate")
    end

    it "returns 422 for invalid params" do
      post "/api/v1/rules",
           params: { rule: { name: "" } }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to be_present
    end
  end

  # ──────────────────────────────────────────────
  # PUT /api/v1/rules/:id
  # ──────────────────────────────────────────────
  describe "PUT /api/v1/rules/:id" do
    let!(:rule) { create(:alert_rule, project: project, severity: "warning") }

    it "updates the rule" do
      put "/api/v1/rules/#{rule.id}",
          params: { rule: { severity: "critical" } }.to_json,
          headers: headers
      expect(response).to have_http_status(:ok)
      expect(rule.reload.severity).to eq("critical")
    end

    it "returns 404 for unknown rule" do
      put "/api/v1/rules/#{SecureRandom.uuid}",
          params: { rule: { severity: "critical" } }.to_json,
          headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ──────────────────────────────────────────────
  # DELETE /api/v1/rules/:id
  # ──────────────────────────────────────────────
  describe "DELETE /api/v1/rules/:id" do
    let!(:rule) { create(:alert_rule, project: project) }

    it "deletes the rule and returns 204" do
      expect {
        delete "/api/v1/rules/#{rule.id}", headers: headers
      }.to change(AlertRule, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/rules/:id/mute
  # ──────────────────────────────────────────────
  describe "POST /api/v1/rules/:id/mute" do
    let!(:rule) { create(:alert_rule, project: project) }

    it "mutes the rule" do
      post "/api/v1/rules/#{rule.id}/mute",
           params: { reason: "Deploy window" }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(rule.reload.muted).to be true
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/rules/:id/unmute
  # ──────────────────────────────────────────────
  describe "POST /api/v1/rules/:id/unmute" do
    let!(:rule) { create(:alert_rule, project: project, :muted) }

    it "unmutes the rule" do
      post "/api/v1/rules/#{rule.id}/unmute",
           params: {}.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(rule.reload.muted).to be false
    end
  end
end
