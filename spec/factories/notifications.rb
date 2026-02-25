FactoryBot.define do
  factory :notification do
    project
    notification_channel
    notification_type { "alert_fired" }
    status { "pending" }
    payload { {} }
    response { {} }
    retry_count { 0 }

    trait :sent do
      status { "sent" }
      sent_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      error_message { "Connection refused" }
      retry_count { 1 }
      next_retry_at { 5.minutes.from_now }
    end

    trait :skipped do
      status { "skipped" }
    end

    trait :for_alert do
      association :alert
    end

    trait :for_incident do
      association :incident
    end
  end
end
