FactoryBot.define do
  factory :alert do
    project
    alert_rule
    sequence(:fingerprint) { |n| "fingerprint-#{n}-#{SecureRandom.hex(4)}" }
    state { "pending" }
    started_at { Time.current }
    acknowledged { false }
    notification_count { 0 }

    trait :pending do
      state { "pending" }
    end

    trait :firing do
      state { "firing" }
      last_fired_at { 5.minutes.ago }
    end

    trait :resolved do
      state { "resolved" }
      resolved_at { 1.hour.ago }
    end

    trait :acknowledged do
      acknowledged { true }
      acknowledged_at { 10.minutes.ago }
      acknowledged_by { "ops@example.com" }
    end

    trait :critical do
      association :alert_rule, factory: [:alert_rule, :critical]
    end

    trait :with_incident do
      association :incident
    end

    trait :with_value do
      current_value { 7.5 }
      threshold_value { 5.0 }
    end
  end
end
