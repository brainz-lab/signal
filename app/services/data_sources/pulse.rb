module DataSources
  class Pulse < Base
    def query(name:, aggregation:, window:, query: {}, group_by: [])
      url = "#{base_url}/api/v1/traces/query"

      params = {
        project_id: @project_id,
        metric: name,
        aggregation: aggregation,
        window: window,
        query: query.to_json,
        group_by: group_by.join(",")
      }

      result = make_request(url, params)
      result["value"]
    rescue => e
      Rails.logger.error("Pulse query error: #{e.message}")
      nil
    end

    def baseline(name:, window:)
      url = "#{base_url}/api/v1/traces/baseline"

      params = {
        project_id: @project_id,
        metric: name,
        window: window
      }

      result = make_request(url, params)
      {
        mean: result["mean"],
        stddev: result["stddev"]
      }
    rescue => e
      Rails.logger.error("Pulse baseline error: #{e.message}")
      { mean: 0, stddev: 1 }
    end

    def last_data_point(name:, query: {})
      url = "#{base_url}/api/v1/traces/last"

      params = {
        project_id: @project_id,
        metric: name,
        query: query.to_json
      }

      result = make_request(url, params)
      {
        timestamp: Time.parse(result["timestamp"]),
        value: result["value"]
      }
    rescue => e
      Rails.logger.error("Pulse last_data_point error: #{e.message}")
      nil
    end

    private

    def base_url
      ENV.fetch("PULSE_URL", "http://pulse:3000")
    end
  end
end
