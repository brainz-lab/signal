module DataSources
  class Reflex < Base
    def query(name:, aggregation:, window:, query: {}, group_by: [])
      url = "#{base_url}/api/v1/errors/query"

      params = {
        project_id: @project_id,
        error_type: name,
        aggregation: aggregation,
        window: window,
        query: query.to_json,
        group_by: group_by.join(",")
      }

      result = make_request(url, params)
      result["value"]
    rescue => e
      Rails.logger.error("Reflex query error: #{e.message}")
      nil
    end

    def baseline(name:, window:)
      url = "#{base_url}/api/v1/errors/baseline"

      params = {
        project_id: @project_id,
        error_type: name,
        window: window
      }

      result = make_request(url, params)
      {
        mean: result["mean"],
        stddev: result["stddev"]
      }
    rescue => e
      Rails.logger.error("Reflex baseline error: #{e.message}")
      { mean: 0, stddev: 1 }
    end

    def last_data_point(name:, query: {})
      url = "#{base_url}/api/v1/errors/last"

      params = {
        project_id: @project_id,
        error_type: name,
        query: query.to_json
      }

      result = make_request(url, params)
      {
        timestamp: Time.parse(result["timestamp"]),
        value: result["value"]
      }
    rescue => e
      Rails.logger.error("Reflex last_data_point error: #{e.message}")
      nil
    end

    private

    def base_url
      ENV.fetch("REFLEX_URL", "http://reflex:3000")
    end
  end
end
