module ApiHelpers
  # Auth header using sig_api_* key stored in project.settings
  def auth_headers(project)
    api_key = project.settings["api_key"]
    { "Authorization" => "Bearer #{api_key}" }
  end

  # Ingest header using sig_ingest_* key stored in project.settings
  def ingest_headers(project)
    ingest_key = project.settings["ingest_key"]
    { "Authorization" => "Bearer #{ingest_key}" }
  end

  # Master key header for platform-facing provisioning endpoints
  def master_key_headers(key = nil)
    key ||= ENV.fetch("SIGNAL_MASTER_KEY", "test_master_key_signal")
    { "X-Master-Key" => key }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
