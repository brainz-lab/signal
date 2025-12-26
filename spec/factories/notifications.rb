FactoryBot.define do
  factory :notification do
    association :notification_channel
    association :alert
    notification_type { 'alert_fired' }
    status { 'pending' }
    project_id { alert.project_id }
    payload { {} }
    response { {} }
    retry_count { 0 }

    trait :sent do
      status { 'sent' }
      sent_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      error_message { 'Connection timeout' }
      retry_count { 3 }
    end

    trait :skipped do
      status { 'skipped' }
    end

    trait :for_incident do
      association :incident
      alert { nil }
      notification_type { 'incident_triggered' }
    end
  end
end
