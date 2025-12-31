module DataSources
  class Flux < Base
    def query(name:, aggregation:, window:, query: {}, group_by: [])
      url = "#{base_url}/api/v1/metrics/query"

      params = {
        project_id: @project_id,
        name: name,
        aggregation: aggregation,
        window: window,
        query: query.to_json,
        group_by: group_by.join(",")
      }

      result = make_request(url, params)
      result["value"]
    rescue => e
      Rails.logger.error("Flux query error: #{e.message}")
      nil
    end

    def baseline(name:, window:)
      url = "#{base_url}/api/v1/metrics/baseline"

      params = {
        project_id: @project_id,
        name: name,
        window: window
      }

      result = make_request(url, params)
      {
        mean: result["mean"],
        stddev: result["stddev"]
      }
    rescue => e
      Rails.logger.error("Flux baseline error: #{e.message}")
      { mean: 0, stddev: 1 }
    end

    def last_data_point(name:, query: {})
      url = "#{base_url}/api/v1/metrics/last"

      params = {
        project_id: @project_id,
        name: name,
        query: query.to_json
      }

      result = make_request(url, params)
      {
        timestamp: Time.parse(result["timestamp"]),
        value: result["value"]
      }
    rescue => e
      Rails.logger.error("Flux last_data_point error: #{e.message}")
      nil
    end

    private

    def base_url
      ENV.fetch("FLUX_URL", "http://flux:3000")
    end
  end
end
