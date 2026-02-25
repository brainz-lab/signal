FactoryBot.define do
  factory :maintenance_window do
    project
    sequence(:name) { |n| "Maintenance Window #{n}" }
    starts_at { 1.hour.from_now }
    ends_at   { 3.hours.from_now }
    active { true }
    rule_ids { [] }

    trait :active_now do
      starts_at { 30.minutes.ago }
      ends_at   { 30.minutes.from_now }
    end

    trait :past do
      starts_at { 3.hours.ago }
      ends_at   { 1.hour.ago }
    end

    trait :inactive do
      active { false }
    end

    trait :covering_all_rules do
      rule_ids { [] }
    end

    trait :covering_specific_rules do
      transient do
        target_rule_ids { [] }
      end
      rule_ids { target_rule_ids }
    end

    trait :recurring do
      recurring { true }
      recurrence_rule { "FREQ=WEEKLY;BYDAY=SA,SU" }
    end
  end
end
