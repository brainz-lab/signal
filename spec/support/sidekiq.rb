require 'sidekiq/testing'

RSpec.configure do |config|
  # Clear all enqueued jobs between tests
  config.before(:each) do
    Sidekiq::Worker.clear_all
  end
end

# Custom matchers for Sidekiq
RSpec::Matchers.define :have_enqueued_sidekiq_job do |job_class|
  match do |_actual|
    job_class.jobs.size > 0
  end

  failure_message do |_actual|
    "expected #{job_class} to have enqueued jobs, but found none"
  end
end
