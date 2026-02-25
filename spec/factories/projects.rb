FactoryBot.define do
  factory :project do
    platform_project_id { SecureRandom.uuid }
    name { "Signal Test Project" }
    environment { "live" }
    settings do
      {
        "api_key"     => "sig_api_#{SecureRandom.hex(24)}",
        "ingest_key"  => "sig_ingest_#{SecureRandom.hex(24)}",
        "allowed_origins" => []
      }
    end

    trait :archived do
      archived_at { 1.day.ago }
    end

    trait :staging do
      environment { "staging" }
    end
  end
end
