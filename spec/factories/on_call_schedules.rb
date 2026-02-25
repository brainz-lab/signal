FactoryBot.define do
  factory :on_call_schedule do
    project
    sequence(:name) { |n| "On-Call Schedule #{n}" }
    slug { name.parameterize }
    schedule_type { "weekly" }
    enabled { true }
    timezone { "UTC" }
    members { [] }
    weekly_schedule { {} }

    trait :weekly do
      schedule_type { "weekly" }
      weekly_schedule do
        {
          "monday"    => { "user" => "alice@example.com" },
          "tuesday"   => { "user" => "alice@example.com" },
          "wednesday" => { "user" => "bob@example.com" },
          "thursday"  => { "user" => "bob@example.com" },
          "friday"    => { "user" => "alice@example.com" },
          "saturday"  => { "user" => "bob@example.com" },
          "sunday"    => { "user" => "bob@example.com" }
        }
      end
    end

    trait :custom_rotation do
      schedule_type { "custom" }
      members { ["alice@example.com", "bob@example.com"] }
      rotation_type { "weekly" }
      rotation_start { 1.week.ago }
    end

    trait :with_current_on_call do
      current_on_call { "alice@example.com" }
      current_shift_start { Time.current.beginning_of_day }
      current_shift_end { Time.current.end_of_day }
    end
  end
end
