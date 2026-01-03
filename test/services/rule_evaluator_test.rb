# frozen_string_literal: true

require "test_helper"

class RuleEvaluatorTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
  end

  # Initialization
  test "initializes with rule" do
    rule = alert_rules(:cpu_threshold)
    evaluator = RuleEvaluator.new(rule)
    assert_not_nil evaluator
  end

  # Threshold evaluation
  test "evaluate_threshold returns firing when value exceeds threshold" do
    rule = alert_rules(:cpu_threshold)
    evaluator = RuleEvaluator.new(rule)

    # Stub data source query to return high value
    DataSources::Flux.any_instance.stubs(:query).returns(95.0)

    result = evaluator.evaluate

    assert_equal "firing", result[:state]
    assert_equal 95.0, result[:value]
    assert_equal rule.threshold, result[:threshold]
    assert_not_nil result[:fingerprint]
  end

  test "evaluate_threshold returns ok when value below threshold" do
    rule = alert_rules(:cpu_threshold)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.stubs(:query).returns(45.0)

    result = evaluator.evaluate

    assert_equal "ok", result[:state]
    assert_equal 45.0, result[:value]
  end

  test "evaluate_threshold handles gt operator" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(operator: "gt", threshold: 80)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.stubs(:query).returns(80.0)
    result = evaluator.evaluate
    assert_equal "ok", result[:state] # 80 is not > 80

    DataSources::Flux.any_instance.stubs(:query).returns(81.0)
    result = evaluator.evaluate
    assert_equal "firing", result[:state] # 81 > 80
  end

  test "evaluate_threshold handles gte operator" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(operator: "gte", threshold: 80)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.stubs(:query).returns(80.0)
    result = evaluator.evaluate
    assert_equal "firing", result[:state] # 80 >= 80

    DataSources::Flux.any_instance.stubs(:query).returns(79.0)
    result = evaluator.evaluate
    assert_equal "ok", result[:state] # 79 is not >= 80
  end

  test "evaluate_threshold handles lt operator" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(operator: "lt", threshold: 10)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.stubs(:query).returns(5.0)
    result = evaluator.evaluate
    assert_equal "firing", result[:state] # 5 < 10

    DataSources::Flux.any_instance.stubs(:query).returns(15.0)
    result = evaluator.evaluate
    assert_equal "ok", result[:state] # 15 is not < 10
  end

  test "evaluate_threshold handles lte operator" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(operator: "lte", threshold: 10)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.stubs(:query).returns(10.0)
    result = evaluator.evaluate
    assert_equal "firing", result[:state] # 10 <= 10
  end

  test "evaluate_threshold handles eq operator" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(operator: "eq", threshold: 50)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.stubs(:query).returns(50.0)
    result = evaluator.evaluate
    assert_equal "firing", result[:state] # 50 == 50

    DataSources::Flux.any_instance.stubs(:query).returns(51.0)
    result = evaluator.evaluate
    assert_equal "ok", result[:state] # 51 != 50
  end

  test "evaluate_threshold handles neq operator" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(operator: "neq", threshold: 0)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.stubs(:query).returns(5.0)
    result = evaluator.evaluate
    assert_equal "firing", result[:state] # 5 != 0

    DataSources::Flux.any_instance.stubs(:query).returns(0.0)
    result = evaluator.evaluate
    assert_equal "ok", result[:state] # 0 is not != 0
  end

  test "evaluate_threshold returns ok for nil value" do
    rule = alert_rules(:cpu_threshold)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.stubs(:query).returns(nil)
    result = evaluator.evaluate

    assert_equal "ok", result[:state]
  end

  # Anomaly evaluation
  test "evaluate_anomaly returns firing when deviation exceeds threshold" do
    rule = alert_rules(:anomaly_detection)
    evaluator = RuleEvaluator.new(rule)

    # With sensitivity=0.8, threshold = 10/0.8 = 12.5 stddevs
    # deviation = (300-100)/10 = 20 stddevs > 12.5 = firing
    DataSources::Pulse.any_instance.stubs(:query).returns(300.0)
    DataSources::Pulse.any_instance.stubs(:baseline).returns({ mean: 100.0, stddev: 10.0 })

    result = evaluator.evaluate

    assert_equal "firing", result[:state]
    assert_equal 300.0, result[:value]
    assert_equal 100.0, result[:expected]
    assert result[:deviation] > 0
  end

  test "evaluate_anomaly returns ok when within normal range" do
    rule = alert_rules(:anomaly_detection)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Pulse.any_instance.stubs(:query).returns(105.0)
    DataSources::Pulse.any_instance.stubs(:baseline).returns({ mean: 100.0, stddev: 10.0 })

    result = evaluator.evaluate

    assert_equal "ok", result[:state]
  end

  test "evaluate_anomaly handles zero stddev" do
    rule = alert_rules(:anomaly_detection)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Pulse.any_instance.stubs(:query).returns(105.0)
    DataSources::Pulse.any_instance.stubs(:baseline).returns({ mean: 100.0, stddev: 0.0 })

    result = evaluator.evaluate

    assert_equal "ok", result[:state]
    assert_equal 0, result[:deviation]
  end

  # Absence evaluation
  test "evaluate_absence returns firing when no data received" do
    rule = alert_rules(:log_absence)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Recall.any_instance.stubs(:last_data_point).returns(nil)

    result = evaluator.evaluate

    assert_equal "firing", result[:state]
    assert_nil result[:last_seen]
  end

  test "evaluate_absence returns firing when data too old" do
    rule = alert_rules(:log_absence)
    rule.update!(expected_interval: "5m")
    evaluator = RuleEvaluator.new(rule)

    DataSources::Recall.any_instance.stubs(:last_data_point).returns({
      timestamp: 10.minutes.ago
    })

    result = evaluator.evaluate

    assert_equal "firing", result[:state]
  end

  test "evaluate_absence returns ok when data is recent" do
    rule = alert_rules(:log_absence)
    rule.update!(expected_interval: "5m")
    evaluator = RuleEvaluator.new(rule)

    DataSources::Recall.any_instance.stubs(:last_data_point).returns({
      timestamp: 1.minute.ago
    })

    result = evaluator.evaluate

    assert_equal "ok", result[:state]
  end

  # Composite evaluation
  test "evaluate_composite with AND operator" do
    rule = AlertRule.new(
      project_id: @project.id,
      name: "Composite AND",
      source: "flux",
      rule_type: "composite",
      severity: "critical",
      composite_operator: "and",
      composite_rules: [
        { source: "flux", rule_type: "threshold", source_name: "cpu", operator: "gt", threshold: 80 },
        { source: "flux", rule_type: "threshold", source_name: "memory", operator: "gt", threshold: 90 }
      ]
    )
    evaluator = RuleEvaluator.new(rule)

    # Both rules fire
    DataSources::Flux.any_instance.stubs(:query).returns(95.0)
    result = evaluator.evaluate
    assert_equal "firing", result[:state]
  end

  test "evaluate_composite with OR operator" do
    rule = AlertRule.new(
      project_id: @project.id,
      name: "Composite OR",
      source: "flux",
      rule_type: "composite",
      severity: "warning",
      composite_operator: "or",
      composite_rules: [
        { source: "flux", rule_type: "threshold", source_name: "cpu", operator: "gt", threshold: 80 },
        { source: "flux", rule_type: "threshold", source_name: "memory", operator: "gt", threshold: 90 }
      ]
    )
    evaluator = RuleEvaluator.new(rule)

    # One rule fires
    DataSources::Flux.any_instance.stubs(:query).returns(85.0)
    result = evaluator.evaluate
    # 85 > 80 for first rule, 85 < 90 for second, but OR means any firing triggers
    assert_equal "firing", result[:state]
  end

  # Data source selection
  test "selects Flux data source for flux rules" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(source: "flux")
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.expects(:query).returns(50.0)
    evaluator.evaluate
  end

  test "selects Pulse data source for pulse rules" do
    rule = alert_rules(:cpu_threshold)
    rule.update!(source: "pulse")
    evaluator = RuleEvaluator.new(rule)

    DataSources::Pulse.any_instance.expects(:query).returns(50.0)
    evaluator.evaluate
  end

  test "selects Reflex data source for reflex rules" do
    rule = alert_rules(:error_rate)
    rule.update!(source: "reflex")
    evaluator = RuleEvaluator.new(rule)

    DataSources::Reflex.any_instance.expects(:query).returns(1.0)
    evaluator.evaluate
  end

  test "selects Recall data source for recall rules" do
    rule = alert_rules(:log_absence)
    rule.update!(source: "recall")
    evaluator = RuleEvaluator.new(rule)

    DataSources::Recall.any_instance.expects(:last_data_point).returns({ timestamp: Time.current })
    evaluator.evaluate
  end

  # Fingerprint generation
  test "generates consistent fingerprint for same inputs" do
    rule = alert_rules(:cpu_threshold)
    evaluator = RuleEvaluator.new(rule)

    DataSources::Flux.any_instance.stubs(:query).returns(95.0)

    result1 = evaluator.evaluate
    result2 = evaluator.evaluate

    assert_equal result1[:fingerprint], result2[:fingerprint]
  end

  # Interval parsing
  test "parses minute intervals" do
    rule = alert_rules(:log_absence)
    rule.update!(expected_interval: "5m")
    evaluator = RuleEvaluator.new(rule)

    # Last data 3 minutes ago - should be OK
    DataSources::Recall.any_instance.stubs(:last_data_point).returns({
      timestamp: 3.minutes.ago
    })
    result = evaluator.evaluate
    assert_equal "ok", result[:state]
  end

  test "parses hour intervals" do
    rule = alert_rules(:log_absence)
    rule.update!(expected_interval: "1h")
    evaluator = RuleEvaluator.new(rule)

    # Last data 30 minutes ago - should be OK
    DataSources::Recall.any_instance.stubs(:last_data_point).returns({
      timestamp: 30.minutes.ago
    })
    result = evaluator.evaluate
    assert_equal "ok", result[:state]
  end

  test "parses day intervals" do
    rule = alert_rules(:log_absence)
    rule.update!(expected_interval: "1d")
    evaluator = RuleEvaluator.new(rule)

    # Last data 12 hours ago - should be OK
    DataSources::Recall.any_instance.stubs(:last_data_point).returns({
      timestamp: 12.hours.ago
    })
    result = evaluator.evaluate
    assert_equal "ok", result[:state]
  end

  test "defaults to 5 minutes for invalid interval" do
    rule = alert_rules(:log_absence)
    rule.update!(expected_interval: "invalid")
    evaluator = RuleEvaluator.new(rule)

    # Last data 3 minutes ago - should be OK with 5 minute default
    DataSources::Recall.any_instance.stubs(:last_data_point).returns({
      timestamp: 3.minutes.ago
    })
    result = evaluator.evaluate
    assert_equal "ok", result[:state]
  end
end
