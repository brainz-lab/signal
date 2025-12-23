module DataSources
  class Recall < Base
    def query(name:, aggregation:, window:, query: {}, group_by: [])
      url = "#{base_url}/api/v1/logs/query"

      params = {
        project_id: @project_id,
        log_level: name,
        aggregation: aggregation,
        window: window,
        query: query.to_json,
        group_by: group_by.join(',')
      }

      result = make_request(url, params)
      result['value']
    rescue => e
      Rails.logger.error("Recall query error: #{e.message}")
      nil
    end

    def baseline(name:, window:)
      url = "#{base_url}/api/v1/logs/baseline"

      params = {
        project_id: @project_id,
        log_level: name,
        window: window
      }

      result = make_request(url, params)
      {
        mean: result['mean'],
        stddev: result['stddev']
      }
    rescue => e
      Rails.logger.error("Recall baseline error: #{e.message}")
      { mean: 0, stddev: 1 }
    end

    def last_data_point(name:, query: {})
      url = "#{base_url}/api/v1/logs/last"

      params = {
        project_id: @project_id,
        log_level: name,
        query: query.to_json
      }

      result = make_request(url, params)
      {
        timestamp: Time.parse(result['timestamp']),
        value: result['value']
      }
    rescue => e
      Rails.logger.error("Recall last_data_point error: #{e.message}")
      nil
    end

    private

    def base_url
      ENV.fetch('RECALL_URL', 'http://recall:3000')
    end
  end
end
