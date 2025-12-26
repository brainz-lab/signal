FactoryBot.define do
  factory :alert_rule do
    sequence(:name) { |n| "Alert Rule #{n}" }
    slug { name.parameterize }
    source { 'flux' }
    rule_type { 'threshold' }
    severity { 'warning' }
    project_id { SecureRandom.uuid }
    enabled { true }
    muted { false }
    operator { 'gt' }
    threshold { 100.0 }
    window { '5m' }
    aggregation { 'avg' }
    evaluation_interval { 60 }
    pending_period { 0 }
    resolve_period { 300 }
    query { { measurement: 'cpu', field: 'usage' } }
    labels { {} }
    annotations { {} }
    notify_channels { [] }

    trait :critical do
      severity { 'critical' }
    end

    trait :info do
      severity { 'info' }
    end

    trait :muted do
      muted { true }
      muted_reason { 'Testing' }
    end

    trait :muted_with_expiry do
      muted { true }
      muted_until { 1.hour.from_now }
    end

    trait :disabled do
      enabled { false }
    end

    trait :anomaly do
      rule_type { 'anomaly' }
      sensitivity { 0.8 }
    end

    trait :absence do
      rule_type { 'absence' }
      expected_interval { '10m' }
    end

    trait :composite do
      rule_type { 'composite' }
      composite_operator { 'AND' }
      composite_rules { [{ rule_id: SecureRandom.uuid }] }
    end

    trait :with_escalation_policy do
      association :escalation_policy
    end
  end
end
