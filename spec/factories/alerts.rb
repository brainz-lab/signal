FactoryBot.define do
  factory :alert do
    association :alert_rule
    sequence(:fingerprint) { |n| Digest::SHA256.hexdigest("alert-#{n}") }
    state { 'pending' }
    project_id { alert_rule.project_id }
    started_at { Time.current }
    current_value { 150.0 }
    threshold_value { 100.0 }
    labels { {} }
    acknowledged { false }
    notification_count { 0 }

    trait :firing do
      state { 'firing' }
      last_fired_at { Time.current }
    end

    trait :resolved do
      state { 'resolved' }
      resolved_at { Time.current }
    end

    trait :acknowledged do
      acknowledged { true }
      acknowledged_at { Time.current }
      acknowledged_by { 'test_user' }
      acknowledgment_note { 'Working on it' }
    end

    trait :with_incident do
      association :incident
    end

    trait :with_labels do
      labels { { host: 'server-01', environment: 'production' } }
    end
  end
end
