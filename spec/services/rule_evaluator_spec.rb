require "rails_helper"

RSpec.describe RuleEvaluator do
  let(:project) { create(:project) }
  let(:evaluator) { described_class.new(rule) }

  # ────────────────────────────────
  # #evaluate — threshold rules
  # ────────────────────────────────
  describe "#evaluate with threshold rules" do
    let(:rule) do
      create(:alert_rule, project: project, rule_type: "threshold",
             source: "pulse", source_name: "error_rate",
             aggregation: "avg", window: "5m",
             operator: "gt", threshold: 5.0)
    end

    let(:data_source) { instance_double(DataSources::Pulse) }

    before do
      allow(DataSources::Pulse).to receive(:new).and_return(data_source)
    end

    context "when value exceeds threshold" do
      it "returns firing state" do
        allow(data_source).to receive(:query).and_return(7.5)
        result = evaluator.evaluate
        expect(result[:state]).to eq("firing")
        expect(result[:value]).to eq(7.5)
      end
    end

    context "when value is below threshold" do
      it "returns ok state" do
        allow(data_source).to receive(:query).and_return(3.0)
        result = evaluator.evaluate
        expect(result[:state]).to eq("ok")
      end
    end

    context "when value is nil (data source unavailable)" do
      it "returns ok state (safe default)" do
        allow(data_source).to receive(:query).and_return(nil)
        result = evaluator.evaluate
        expect(result[:state]).to eq("ok")
      end
    end

    it "includes a fingerprint in the result" do
      allow(data_source).to receive(:query).and_return(3.0)
      result = evaluator.evaluate
      expect(result[:fingerprint]).to be_a(String)
      expect(result[:fingerprint]).not_to be_empty
    end
  end

  # ────────────────────────────────
  # compare — all operators
  # ────────────────────────────────
  describe "compare (via threshold evaluation)" do
    operators = {
      "gt"  => { passing: [6.0, 5.1], failing: [5.0, 4.9] },
      "gte" => { passing: [5.0, 6.0], failing: [4.9] },
      "lt"  => { passing: [4.9, 3.0], failing: [5.0, 6.0] },
      "lte" => { passing: [5.0, 4.9], failing: [5.1] },
      "eq"  => { passing: [5.0], failing: [4.9, 5.1] },
      "neq" => { passing: [4.9, 5.1], failing: [5.0] }
    }

    operators.each do |op, cases|
      context "with operator '#{op}'" do
        let(:rule) do
          create(:alert_rule, project: project, rule_type: "threshold",
                 source: "pulse", operator: op, threshold: 5.0)
        end
        let(:ds) { instance_double(DataSources::Pulse) }

        before { allow(DataSources::Pulse).to receive(:new).and_return(ds) }

        cases[:passing].each do |val|
          it "fires when value is #{val}" do
            allow(ds).to receive(:query).and_return(val)
            expect(evaluator.evaluate[:state]).to eq("firing")
          end
        end

        cases[:failing].each do |val|
          it "does not fire when value is #{val}" do
            allow(ds).to receive(:query).and_return(val)
            expect(evaluator.evaluate[:state]).to eq("ok")
          end
        end
      end
    end
  end

  # ────────────────────────────────
  # #evaluate — anomaly rules
  # ────────────────────────────────
  describe "#evaluate with anomaly rules" do
    let(:rule) do
      create(:alert_rule, project: project, :anomaly, source: "pulse",
             source_name: "response_time", sensitivity: 1.0)
    end
    let(:ds) { instance_double(DataSources::Pulse) }

    before { allow(DataSources::Pulse).to receive(:new).and_return(ds) }

    it "returns firing when deviation exceeds threshold" do
      allow(ds).to receive(:query).and_return(50.0)  # current
      allow(ds).to receive(:baseline).and_return({ mean: 20.0, stddev: 2.0 })
      result = evaluator.evaluate
      expect(result[:state]).to eq("firing")
    end

    it "returns ok when deviation is within threshold" do
      allow(ds).to receive(:query).and_return(21.0)  # barely above mean
      allow(ds).to receive(:baseline).and_return({ mean: 20.0, stddev: 2.0 })
      result = evaluator.evaluate
      expect(result[:state]).to eq("ok")
    end
  end

  # ────────────────────────────────
  # #evaluate — absence rules
  # ────────────────────────────────
  describe "#evaluate with absence rules" do
    let(:rule) do
      create(:alert_rule, project: project, :absence, source: "pulse",
             source_name: "heartbeat", expected_interval: "5m")
    end
    let(:ds) { instance_double(DataSources::Pulse) }

    before { allow(DataSources::Pulse).to receive(:new).and_return(ds) }

    it "returns firing when no data point exists" do
      allow(ds).to receive(:last_data_point).and_return(nil)
      result = evaluator.evaluate
      expect(result[:state]).to eq("firing")
    end

    it "returns firing when last data point is older than interval" do
      allow(ds).to receive(:last_data_point)
        .and_return({ timestamp: 10.minutes.ago, value: 1 })
      result = evaluator.evaluate
      expect(result[:state]).to eq("firing")
    end

    it "returns ok when last data point is within the interval" do
      allow(ds).to receive(:last_data_point)
        .and_return({ timestamp: 1.minute.ago, value: 1 })
      result = evaluator.evaluate
      expect(result[:state]).to eq("ok")
    end
  end

  # ────────────────────────────────
  # Data source routing
  # ────────────────────────────────
  describe "data source selection" do
    {
      "flux"   => DataSources::Flux,
      "pulse"  => DataSources::Pulse,
      "reflex" => DataSources::Reflex,
      "recall" => DataSources::Recall
    }.each do |source, klass|
      it "instantiates #{klass} for source '#{source}'" do
        rule = create(:alert_rule, project: project, source: source)
        ds   = instance_double(klass)
        allow(klass).to receive(:new).and_return(ds)
        allow(ds).to receive(:query).and_return(nil)
        described_class.new(rule).evaluate
        expect(klass).to have_received(:new).with(project.id)
      end
    end
  end
end
