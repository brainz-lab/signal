FactoryBot.define do
  factory :alert_rule do
    project
    sequence(:name) { |n| "Alert Rule #{n}" }
    slug { name.parameterize }
    source { "pulse" }
    rule_type { "threshold" }
    severity { "warning" }
    enabled { true }
    muted { false }
    operator { "gt" }
    threshold { 5.0 }
    window { "5m" }
    aggregation { "avg" }
    source_name { "error_rate" }
    pending_period { 0 }
    resolve_period { 300 }
    notify_channels { [] }

    trait :critical do
      severity { "critical" }
    end

    trait :info do
      severity { "info" }
    end

    trait :anomaly do
      rule_type { "anomaly" }
      sensitivity { 0.8 }
      baseline_window { "1h" }
    end

    trait :absence do
      rule_type { "absence" }
      expected_interval { "5m" }
    end

    trait :composite do
      rule_type { "composite" }
      composite_operator { "AND" }
      composite_rules { [] }
    end

    trait :disabled do
      enabled { false }
    end

    trait :muted do
      muted { true }
      muted_reason { "Scheduled maintenance" }
    end

    trait :muted_temporarily do
      muted { true }
      muted_until { 1.hour.from_now }
      muted_reason { "Deploy in progress" }
    end

    trait :with_escalation do
      association :escalation_policy
    end

    trait :flux_source do
      source { "flux" }
    end

    trait :reflex_source do
      source { "reflex" }
    end

    trait :recall_source do
      source { "recall" }
    end
  end
end
