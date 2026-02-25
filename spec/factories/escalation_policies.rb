FactoryBot.define do
  factory :escalation_policy do
    project
    sequence(:name) { |n| "Policy #{n}" }
    slug { name.parameterize }
    enabled { true }
    steps { [] }
    repeat { false }

    trait :with_steps do
      steps do
        [
          { "wait_minutes" => 5, "notify" => "on_call" },
          { "wait_minutes" => 10, "notify" => "email", "targets" => ["ops@example.com"] }
        ]
      end
    end

    trait :repeating do
      repeat { true }
      max_repeats { 3 }
      repeat_after_minutes { 15 }
    end
  end
end
