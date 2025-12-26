FactoryBot.define do
  factory :escalation_policy do
    sequence(:name) { |n| "Escalation Policy #{n}" }
    slug { name.parameterize }
    description { 'Standard escalation policy' }
    project_id { SecureRandom.uuid }
    enabled { true }
    repeat { false }
    steps { [
      { level: 1, wait_minutes: 0, notify: ['user1'] },
      { level: 2, wait_minutes: 5, notify: ['user2'] }
    ] }

    trait :with_repeat do
      repeat { true }
      repeat_after_minutes { 30 }
      max_repeats { 3 }
    end

    trait :disabled do
      enabled { false }
    end
  end
end
