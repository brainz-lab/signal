FactoryBot.define do
  factory :on_call_schedule do
    sequence(:name) { |n| "On-Call Schedule #{n}" }
    slug { name.parameterize }
    project_id { SecureRandom.uuid }
    schedule_type { 'weekly' }
    enabled { true }
    timezone { 'UTC' }
    weekly_schedule { {
      'monday' => { 'user' => 'user1' },
      'tuesday' => { 'user' => 'user1' },
      'wednesday' => { 'user' => 'user2' },
      'thursday' => { 'user' => 'user2' },
      'friday' => { 'user' => 'user3' },
      'saturday' => { 'user' => 'user3' },
      'sunday' => { 'user' => 'user3' }
    } }
    members { [] }

    trait :custom do
      schedule_type { 'custom' }
      members { ['user1', 'user2', 'user3'] }
      rotation_type { 'daily' }
      rotation_start { Time.current.beginning_of_day }
      current_on_call { 'user1' }
      current_shift_start { Time.current.beginning_of_day }
      current_shift_end { 1.day.from_now.beginning_of_day }
    end

    trait :weekly_rotation do
      schedule_type { 'custom' }
      members { ['user1', 'user2', 'user3'] }
      rotation_type { 'weekly' }
      rotation_start { Time.current.beginning_of_week }
      current_on_call { 'user1' }
      current_shift_start { Time.current.beginning_of_week }
      current_shift_end { 1.week.from_now.beginning_of_week }
    end

    trait :disabled do
      enabled { false }
    end
  end
end
