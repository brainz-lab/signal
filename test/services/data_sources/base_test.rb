# frozen_string_literal: true

require "test_helper"

class DataSources::BaseTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
  end

  # Test concrete data source for Base behavior
  class TestDataSource < DataSources::Base
    def query(name:, aggregation:, window:, query: {}, group_by: [])
      # Simplified implementation for testing
      50.0
    end

    def baseline(name:, window:)
      { mean: 100.0, stddev: 10.0 }
    end

    def last_data_point(name:, query: {})
      { timestamp: Time.current, value: 42.0 }
    end
  end

  # Initialization
  test "initializes with project_id" do
    ds = TestDataSource.new(@project.id)
    assert_not_nil ds
  end

  # Window parsing
  test "parses minute window" do
    ds = TestDataSource.new(@project.id)
    result = ds.send(:parse_window, "5m")

    assert_equal 5.minutes, result
  end

  test "parses hour window" do
    ds = TestDataSource.new(@project.id)
    result = ds.send(:parse_window, "2h")

    assert_equal 2.hours, result
  end

  test "parses day window" do
    ds = TestDataSource.new(@project.id)
    result = ds.send(:parse_window, "7d")

    assert_equal 7.days, result
  end

  test "returns 5 minutes for invalid window" do
    ds = TestDataSource.new(@project.id)
    result = ds.send(:parse_window, "invalid")

    assert_equal 5.minutes, result
  end

  test "returns 5 minutes for nil window" do
    ds = TestDataSource.new(@project.id)
    result = ds.send(:parse_window, nil)

    assert_equal 5.minutes, result
  end

  test "returns 5 minutes for empty window" do
    ds = TestDataSource.new(@project.id)
    result = ds.send(:parse_window, "")

    assert_equal 5.minutes, result
  end

  # API key
  test "api_key returns environment variable" do
    ENV["BRAINZLAB_API_KEY"] = "test_api_key"

    ds = TestDataSource.new(@project.id)
    assert_equal "test_api_key", ds.send(:api_key)
  ensure
    ENV.delete("BRAINZLAB_API_KEY")
  end

  # Make request (with stubbing)
  test "make_request adds authorization header" do
    ENV["BRAINZLAB_API_KEY"] = "test_api_key"

    stub_request(:get, "https://api.example.com/data")
      .with(headers: { "Authorization" => "Bearer test_api_key" })
      .to_return(status: 200, body: '{"result": 42}')

    ds = TestDataSource.new(@project.id)
    result = ds.send(:make_request, "https://api.example.com/data")

    assert_equal({ "result" => 42 }, result)
  ensure
    ENV.delete("BRAINZLAB_API_KEY")
  end

  test "make_request raises error on non-success status" do
    ENV["BRAINZLAB_API_KEY"] = "test_api_key"

    stub_request(:get, "https://api.example.com/data")
      .to_return(status: 500, body: "Server Error")

    ds = TestDataSource.new(@project.id)

    assert_raises RuntimeError do
      ds.send(:make_request, "https://api.example.com/data")
    end
  ensure
    ENV.delete("BRAINZLAB_API_KEY")
  end

  test "make_request parses JSON response" do
    ENV["BRAINZLAB_API_KEY"] = "test_api_key"

    stub_request(:get, "https://api.example.com/data")
      .to_return(
        status: 200,
        body: '{"values": [1, 2, 3], "meta": {"count": 3}}',
        headers: { "Content-Type" => "application/json" }
      )

    ds = TestDataSource.new(@project.id)
    result = ds.send(:make_request, "https://api.example.com/data")

    assert_equal [ 1, 2, 3 ], result["values"]
    assert_equal 3, result["meta"]["count"]
  ensure
    ENV.delete("BRAINZLAB_API_KEY")
  end

  test "make_request passes query params" do
    ENV["BRAINZLAB_API_KEY"] = "test_api_key"

    stub_request(:get, "https://api.example.com/data")
      .with(query: { "window" => "5m", "name" => "cpu" })
      .to_return(status: 200, body: '{}')

    ds = TestDataSource.new(@project.id)
    ds.send(:make_request, "https://api.example.com/data", { window: "5m", name: "cpu" })

    assert_requested :get, "https://api.example.com/data?name=cpu&window=5m"
  ensure
    ENV.delete("BRAINZLAB_API_KEY")
  end

  # Abstract methods raise NotImplementedError in real Base
  test "base query raises NotImplementedError" do
    ds = DataSources::Base.new(@project.id)

    assert_raises NotImplementedError do
      ds.query(name: "test", aggregation: "avg", window: "5m")
    end
  end

  test "base baseline raises NotImplementedError" do
    ds = DataSources::Base.new(@project.id)

    assert_raises NotImplementedError do
      ds.baseline(name: "test", window: "7d")
    end
  end

  test "base last_data_point raises NotImplementedError" do
    ds = DataSources::Base.new(@project.id)

    assert_raises NotImplementedError do
      ds.last_data_point(name: "test")
    end
  end
end
