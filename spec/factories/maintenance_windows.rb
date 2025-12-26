FactoryBot.define do
  factory :maintenance_window do
    sequence(:name) { |n| "Maintenance Window #{n}" }
    description { 'Scheduled maintenance' }
    project_id { SecureRandom.uuid }
    starts_at { 1.hour.from_now }
    ends_at { 3.hours.from_now }
    active { true }
    recurring { false }
    rule_ids { [] }
    services { [] }

    trait :current do
      starts_at { 1.hour.ago }
      ends_at { 1.hour.from_now }
    end

    trait :past do
      starts_at { 3.hours.ago }
      ends_at { 1.hour.ago }
    end

    trait :future do
      starts_at { 2.hours.from_now }
      ends_at { 4.hours.from_now }
    end

    trait :inactive do
      active { false }
    end

    trait :recurring do
      recurring { true }
      recurrence_rule { 'FREQ=WEEKLY;BYDAY=SU' }
    end

    trait :with_rule_ids do
      rule_ids { [SecureRandom.uuid, SecureRandom.uuid] }
    end
  end
end
