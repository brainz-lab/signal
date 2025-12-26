FactoryBot.define do
  factory :notification_channel do
    sequence(:name) { |n| "Channel #{n}" }
    slug { name.parameterize }
    channel_type { 'slack' }
    project_id { SecureRandom.uuid }
    enabled { true }
    verified { false }
    config { { webhook_url: 'https://hooks.slack.com/services/test' } }
    success_count { 0 }
    failure_count { 0 }

    trait :email do
      channel_type { 'email' }
      config { { to: 'test@example.com' } }
    end

    trait :webhook do
      channel_type { 'webhook' }
      config { { url: 'https://example.com/webhook' } }
    end

    trait :pagerduty do
      channel_type { 'pagerduty' }
      config { { integration_key: 'test_key' } }
    end

    trait :discord do
      channel_type { 'discord' }
      config { { webhook_url: 'https://discord.com/api/webhooks/test' } }
    end

    trait :teams do
      channel_type { 'teams' }
      config { { webhook_url: 'https://outlook.office.com/webhook/test' } }
    end

    trait :opsgenie do
      channel_type { 'opsgenie' }
      config { { api_key: 'test_api_key' } }
    end

    trait :verified do
      verified { true }
      last_tested_at { Time.current }
      last_test_status { 'success' }
    end

    trait :disabled do
      enabled { false }
    end
  end
end
