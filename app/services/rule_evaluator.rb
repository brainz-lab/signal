class RuleEvaluator
  def initialize(rule)
    @rule = rule
    @project_id = rule.project_id
  end

  def evaluate
    data_source = get_data_source

    case @rule.rule_type
    when "threshold"
      evaluate_threshold(data_source)
    when "anomaly"
      evaluate_anomaly(data_source)
    when "absence"
      evaluate_absence(data_source)
    when "composite"
      evaluate_composite
    end
  end

  private

  def get_data_source
    case @rule.source
    when "flux" then DataSources::Flux.new(@project_id)
    when "pulse" then DataSources::Pulse.new(@project_id)
    when "reflex" then DataSources::Reflex.new(@project_id)
    when "recall" then DataSources::Recall.new(@project_id)
    end
  end

  def evaluate_threshold(data_source)
    value = data_source.query(
      name: @rule.source_name,
      aggregation: @rule.aggregation,
      window: @rule.window,
      query: @rule.query,
      group_by: @rule.group_by
    )

    triggered = compare(value, @rule.operator, @rule.threshold)

    {
      state: triggered ? "firing" : "ok",
      value: value,
      threshold: @rule.threshold,
      fingerprint: generate_fingerprint(value),
      labels: @rule.group_by.present? ? value[:labels] : {}
    }
  end

  def evaluate_anomaly(data_source)
    current = data_source.query(
      name: @rule.source_name,
      aggregation: "avg",
      window: @rule.window,
      query: @rule.query
    )

    baseline = data_source.baseline(
      name: @rule.source_name,
      window: @rule.baseline_window
    )

    deviation = calculate_deviation(current, baseline)
    threshold = 10.0 / @rule.sensitivity  # Higher sensitivity = lower threshold

    triggered = deviation.abs > threshold

    {
      state: triggered ? "firing" : "ok",
      value: current,
      expected: baseline[:mean],
      deviation: deviation,
      fingerprint: generate_fingerprint(current),
      labels: {}
    }
  end

  def evaluate_absence(data_source)
    last_data = data_source.last_data_point(
      name: @rule.source_name,
      query: @rule.query
    )

    interval = parse_interval(@rule.expected_interval)
    triggered = last_data.nil? || last_data[:timestamp] < interval.ago

    {
      state: triggered ? "firing" : "ok",
      value: nil,
      last_seen: last_data&.dig(:timestamp),
      fingerprint: generate_fingerprint(nil),
      labels: {}
    }
  end

  def evaluate_composite
    results = @rule.composite_rules.map do |sub_rule|
      sub_evaluator = RuleEvaluator.new(
        AlertRule.new(sub_rule.merge(project_id: @project_id))
      )
      sub_evaluator.evaluate
    end

    all_firing = results.all? { |r| r[:state] == "firing" }
    any_firing = results.any? { |r| r[:state] == "firing" }

    triggered = @rule.composite_operator == "and" ? all_firing : any_firing

    {
      state: triggered ? "firing" : "ok",
      sub_results: results,
      fingerprint: generate_fingerprint(results),
      labels: {}
    }
  end

  def compare(value, operator, threshold)
    return false if value.nil?

    case operator
    when "gt" then value > threshold
    when "gte" then value >= threshold
    when "lt" then value < threshold
    when "lte" then value <= threshold
    when "eq" then value == threshold
    when "neq" then value != threshold
    else false
    end
  end

  def calculate_deviation(current, baseline)
    return 0 if baseline[:stddev].nil? || baseline[:stddev].zero?
    (current - baseline[:mean]) / baseline[:stddev]
  end

  def generate_fingerprint(value)
    Digest::SHA256.hexdigest("#{@rule.id}:#{@rule.group_by}:#{value}")
  end

  def parse_interval(interval)
    match = interval&.match(/^(\d+)(m|h|d)$/)
    return 5.minutes unless match

    value = match[1].to_i
    case match[2]
    when "m" then value.minutes
    when "h" then value.hours
    when "d" then value.days
    end
  end
end
