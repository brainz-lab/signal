FactoryBot.define do
  factory :alert_history do
    project
    alert_rule
    state { "ok" }
    timestamp { Time.current }
    value { nil }
    labels { {} }
    fingerprint { "fp-#{SecureRandom.hex(8)}" }

    trait :ok do
      state { "ok" }
    end

    trait :pending do
      state { "pending" }
      value { 4.8 }
    end

    trait :firing do
      state { "firing" }
      value { 7.2 }
    end
  end
end
