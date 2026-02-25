FactoryBot.define do
  factory :notification_channel do
    project
    sequence(:name) { |n| "Channel #{n}" }
    slug { name.parameterize }
    channel_type { "webhook" }
    config { { "url" => "https://hooks.example.com/test" } }
    enabled { true }
    verified { false }

    trait :slack do
      channel_type { "slack" }
      sequence(:name) { |n| "Slack Channel #{n}" }
      config { { "webhook_url" => "https://hooks.slack.com/services/T00/B00/XXX" } }
    end

    trait :pagerduty do
      channel_type { "pagerduty" }
      sequence(:name) { |n| "PagerDuty #{n}" }
      config { { "integration_key" => "abc123def456abc123def456abc123de" } }
    end

    trait :email do
      channel_type { "email" }
      sequence(:name) { |n| "Email Channel #{n}" }
      config { { "recipients" => ["ops@example.com"] } }
    end

    trait :webhook do
      channel_type { "webhook" }
      sequence(:name) { |n| "Webhook #{n}" }
      config { { "url" => "https://example.com/webhook" } }
    end

    trait :disabled do
      enabled { false }
    end

    trait :verified do
      verified { true }
      last_test_status { "success" }
      last_tested_at { 1.hour.ago }
    end
  end
end
