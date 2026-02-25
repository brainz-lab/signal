require "rails_helper"

RSpec.describe "API V1 Channels", type: :request do
  let(:project) { create(:project) }
  let(:headers) { auth_headers(project).merge("Content-Type" => "application/json") }

  # ──────────────────────────────────────────────
  # GET /api/v1/channels
  # ──────────────────────────────────────────────
  describe "GET /api/v1/channels" do
    let!(:slack_channel)   { create(:notification_channel, :slack, project: project) }
    let!(:webhook_channel) { create(:notification_channel, :webhook, project: project) }

    it "returns all channels for the project" do
      get "/api/v1/channels", headers: headers
      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["channels"].map { |c| c["id"] }
      expect(ids).to include(slack_channel.id, webhook_channel.id)
    end

    it "does not expose channels from other projects" do
      other = create(:notification_channel)
      get "/api/v1/channels", headers: headers
      ids = response.parsed_body["channels"].map { |c| c["id"] }
      expect(ids).not_to include(other.id)
    end

    it "returns 401 without authentication" do
      get "/api/v1/channels"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/channels/:id
  # ──────────────────────────────────────────────
  describe "GET /api/v1/channels/:id" do
    let!(:channel) { create(:notification_channel, :slack, project: project) }

    it "returns channel details with masked config" do
      get "/api/v1/channels/#{channel.id}", headers: headers
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["id"]).to eq(channel.id)
      expect(body["channel_type"]).to eq("slack")
      expect(body).to have_key("config")
    end

    it "returns 404 for unknown channel" do
      get "/api/v1/channels/#{SecureRandom.uuid}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "does not expose channels from other projects" do
      other = create(:notification_channel)
      get "/api/v1/channels/#{other.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/channels
  # ──────────────────────────────────────────────
  describe "POST /api/v1/channels" do
    let(:payload) do
      {
        channel: {
          name: "Ops Webhook",
          channel_type: "webhook",
          config: { url: "https://example.com/webhook" }
        }
      }
    end

    it "creates a new channel and returns 201" do
      expect {
        post "/api/v1/channels", params: payload.to_json, headers: headers
      }.to change(NotificationChannel, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["name"]).to eq("Ops Webhook")
      expect(response.parsed_body["channel_type"]).to eq("webhook")
    end

    it "returns 422 for invalid params" do
      post "/api/v1/channels",
           params: { channel: { name: "" } }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ──────────────────────────────────────────────
  # PUT /api/v1/channels/:id
  # ──────────────────────────────────────────────
  describe "PUT /api/v1/channels/:id" do
    let!(:channel) { create(:notification_channel, :webhook, project: project) }

    it "updates the channel" do
      put "/api/v1/channels/#{channel.id}",
          params: { channel: { name: "Updated Name" } }.to_json,
          headers: headers
      expect(response).to have_http_status(:ok)
      expect(channel.reload.name).to eq("Updated Name")
    end
  end

  # ──────────────────────────────────────────────
  # DELETE /api/v1/channels/:id
  # ──────────────────────────────────────────────
  describe "DELETE /api/v1/channels/:id" do
    let!(:channel) { create(:notification_channel, :webhook, project: project) }

    it "deletes the channel and returns 204" do
      expect {
        delete "/api/v1/channels/#{channel.id}", headers: headers
      }.to change(NotificationChannel, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/channels/:id/test
  # ──────────────────────────────────────────────
  describe "POST /api/v1/channels/:id/test" do
    let!(:channel) { create(:notification_channel, :webhook, project: project) }

    before do
      stub_request(:post, channel.config["url"])
        .to_return(status: 200, body: '{"ok":true}')
    end

    it "tests the channel and returns success" do
      post "/api/v1/channels/#{channel.id}/test",
           params: {}.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["success"]).to be true
    end
  end
end
