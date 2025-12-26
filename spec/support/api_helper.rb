module ApiHelper
  def api_headers(project_id = nil)
    headers = {
      'Authorization' => 'Bearer test-token',
      'Content-Type' => 'application/json'
    }
    headers['X-Project-ID'] = project_id if project_id
    headers
  end

  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include ApiHelper, type: :controller
  config.include ApiHelper, type: :request
end
