FactoryBot.define do
  factory :incident do
    sequence(:title) { |n| "Incident #{n}" }
    summary { 'High CPU usage detected' }
    status { 'triggered' }
    severity { 'warning' }
    project_id { SecureRandom.uuid }
    triggered_at { Time.current }
    timeline { [{ at: Time.current.iso8601, type: 'triggered', message: 'Incident triggered' }] }
    affected_services { [] }

    trait :acknowledged do
      status { 'acknowledged' }
      acknowledged_at { Time.current }
      acknowledged_by { 'test_user' }
      timeline { [
        { at: 2.minutes.ago.iso8601, type: 'triggered', message: 'Incident triggered' },
        { at: Time.current.iso8601, type: 'acknowledged', by: 'test_user' }
      ] }
    end

    trait :resolved do
      status { 'resolved' }
      resolved_at { Time.current }
      resolved_by { 'test_user' }
      resolution_note { 'Fixed the issue' }
      timeline { [
        { at: 5.minutes.ago.iso8601, type: 'triggered', message: 'Incident triggered' },
        { at: Time.current.iso8601, type: 'resolved', by: 'test_user', message: 'Fixed the issue' }
      ] }
    end

    trait :critical do
      severity { 'critical' }
    end

    trait :info do
      severity { 'info' }
    end

    trait :with_affected_services do
      affected_services { ['api', 'web'] }
    end
  end
end
