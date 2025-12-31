module DataSources
  class Base
    def initialize(project_id)
      @project_id = project_id
    end

    def query(name:, aggregation:, window:, query: {}, group_by: [])
      raise NotImplementedError
    end

    def baseline(name:, window:)
      raise NotImplementedError
    end

    def last_data_point(name:, query: {})
      raise NotImplementedError
    end

    protected

    def api_key
      ENV["BRAINZLAB_API_KEY"]
    end

    def parse_window(window)
      match = window&.match(/^(\d+)(m|h|d)$/)
      return 5.minutes unless match

      value = match[1].to_i
      case match[2]
      when "m" then value.minutes
      when "h" then value.hours
      when "d" then value.days
      end
    end

    def make_request(url, params = {})
      response = HTTP.auth("Bearer #{api_key}").get(url, params: params)
      raise "API error: #{response.status}" unless response.status.success?
      JSON.parse(response.body)
    end
  end
end
