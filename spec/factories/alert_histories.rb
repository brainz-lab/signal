FactoryBot.define do
  factory :alert_history do
    association :alert_rule
    project_id { alert_rule.project_id }
    sequence(:fingerprint) { |n| Digest::SHA256.hexdigest("history-#{n}") }
    state { 'ok' }
    timestamp { Time.current }
    value { 50.0 }
    labels { {} }

    trait :firing do
      state { 'firing' }
      value { 150.0 }
    end

    trait :with_labels do
      labels { { host: 'server-01', environment: 'production' } }
    end
  end
end
