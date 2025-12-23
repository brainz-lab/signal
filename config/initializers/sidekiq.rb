Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  # Schedule recurring jobs
  config.on(:startup) do
    Sidekiq::Cron::Job.create(
      name: 'Rule Evaluation - every minute',
      cron: '* * * * *',
      class: 'RuleEvaluationJob'
    ) if defined?(Sidekiq::Cron)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
