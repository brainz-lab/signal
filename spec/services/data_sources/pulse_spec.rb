require "rails_helper"

RSpec.describe DataSources::Pulse do
  let(:project)    { create(:project) }
  let(:project_id) { project.id }
  let(:pulse_url)  { ENV.fetch("PULSE_URL", "http://pulse:3000") }
  let(:api_key)    { "brainzlab_api_key" }
  let(:data_source) { described_class.new(project_id) }

  before do
    stub_const("ENV", ENV.to_h.merge("BRAINZLAB_API_KEY" => api_key))
  end

  # ────────────────────────────────
  # #query
  # ────────────────────────────────
  describe "#query" do
    let(:query_url) { "#{pulse_url}/api/v1/traces/query" }

    it "returns the value from Pulse API" do
      stub_request(:get, query_url)
        .with(query: hash_including("metric" => "error_rate"))
        .to_return(status: 200, body: '{"value":3.5}',
                   headers: { "Content-Type" => "application/json" })

      result = data_source.query(name: "error_rate", aggregation: "avg", window: "5m")
      expect(result).to eq(3.5)
    end

    it "returns nil when Pulse is unavailable" do
      stub_request(:get, query_url).to_return(status: 500, body: "Error")
      result = data_source.query(name: "error_rate", aggregation: "avg", window: "5m")
      expect(result).to be_nil
    end

    it "returns nil on network error" do
      stub_request(:get, query_url).to_timeout
      result = data_source.query(name: "error_rate", aggregation: "avg", window: "5m")
      expect(result).to be_nil
    end
  end

  # ────────────────────────────────
  # #baseline
  # ────────────────────────────────
  describe "#baseline" do
    let(:baseline_url) { "#{pulse_url}/api/v1/traces/baseline" }

    it "returns mean and stddev from Pulse API" do
      stub_request(:get, baseline_url)
        .to_return(status: 200, body: '{"mean":250.0,"stddev":30.0}',
                   headers: { "Content-Type" => "application/json" })

      result = data_source.baseline(name: "response_time", window: "1h")
      expect(result[:mean]).to eq(250.0)
      expect(result[:stddev]).to eq(30.0)
    end

    it "returns default baseline on error" do
      stub_request(:get, baseline_url).to_return(status: 500, body: "Error")
      result = data_source.baseline(name: "response_time", window: "1h")
      expect(result[:mean]).to eq(0)
      expect(result[:stddev]).to eq(1)
    end
  end

  # ────────────────────────────────
  # #last_data_point
  # ────────────────────────────────
  describe "#last_data_point" do
    let(:last_url)  { "#{pulse_url}/api/v1/traces/last" }
    let(:timestamp) { 2.minutes.ago.iso8601 }

    it "returns parsed timestamp and value" do
      stub_request(:get, last_url)
        .to_return(status: 200,
                   body: { "timestamp" => timestamp, "value" => 1 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = data_source.last_data_point(name: "heartbeat")
      expect(result[:timestamp]).to be_a(Time)
      expect(result[:value]).to eq(1)
    end

    it "returns nil on error" do
      stub_request(:get, last_url).to_return(status: 404, body: "Not found")
      result = data_source.last_data_point(name: "heartbeat")
      expect(result).to be_nil
    end
  end
end
