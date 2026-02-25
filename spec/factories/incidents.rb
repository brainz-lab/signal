FactoryBot.define do
  factory :incident do
    project
    title { "High error rate detected" }
    severity { "warning" }
    status { "triggered" }
    triggered_at { Time.current }
    timeline { [] }

    trait :critical do
      severity { "critical" }
      title { "Critical: Service Down" }
    end

    trait :acknowledged do
      status { "acknowledged" }
      acknowledged_at { 5.minutes.ago }
      acknowledged_by { "ops@example.com" }
    end

    trait :resolved do
      status { "resolved" }
      resolved_at { 1.hour.ago }
      resolved_by { "ops@example.com" }
      resolution_note { "Fixed by rollback" }
    end

    trait :with_timeline do
      timeline do
        [
          { "at" => 30.minutes.ago.iso8601, "type" => "triggered", "by" => nil },
          { "at" => 20.minutes.ago.iso8601, "type" => "acknowledged", "by" => "ops@example.com" }
        ]
      end
    end
  end
end
