# frozen_string_literal: true

require "test_helper"

class Api::V1::ChannelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:acme)
    # Create fresh channel to avoid encryption key mismatch with fixtures
    @channel = NotificationChannel.create!(
      project: @project,
      name: "Test Slack Channel",
      channel_type: "slack",
      config: { webhook_url: "https://hooks.slack.com/services/test" }
    )
  end

  # Index
  test "index returns list of channels" do
    get api_v1_channels_url, headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json["channels"].is_a?(Array)
  end

  # Show
  test "show returns channel details" do
    get api_v1_channel_url(@channel.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @channel.id, json["id"]
    assert_equal @channel.name, json["name"]
    assert_equal @channel.channel_type, json["channel_type"]
  end

  test "show returns 404 for non-existent channel" do
    get api_v1_channel_url("non-existent-uuid"), headers: auth_headers
    assert_response :not_found
  end

  # Create
  test "create creates new channel" do
    channel_params = {
      channel: {
        name: "New Slack Channel",
        channel_type: "slack",
        config: { webhook_url: "https://hooks.slack.com/new" }
      }
    }

    assert_difference "NotificationChannel.count", 1 do
      post api_v1_channels_url, headers: auth_headers, params: channel_params
    end
    assert_response :created

    json = JSON.parse(response.body)
    assert_equal "New Slack Channel", json["name"]
  end

  test "create returns errors for invalid params" do
    channel_params = {
      channel: {
        name: "",
        channel_type: "invalid"
      }
    }

    assert_no_difference "NotificationChannel.count" do
      post api_v1_channels_url, headers: auth_headers, params: channel_params
    end
    assert_response :unprocessable_entity
  end

  # Update
  test "update updates channel" do
    patch api_v1_channel_url(@channel.id), headers: auth_headers,
      params: { channel: { name: "Updated Name" } }
    assert_response :success

    @channel.reload
    assert_equal "Updated Name", @channel.name
  end

  # Destroy
  test "destroy deletes channel" do
    channel_to_delete = NotificationChannel.create!(
      project_id: @project.id,
      name: "To Delete",
      channel_type: "slack"
    )

    assert_difference "NotificationChannel.count", -1 do
      delete api_v1_channel_url(channel_to_delete.id), headers: auth_headers
    end
    assert_response :no_content
  end

  # Test
  test "test sends test notification" do
    stub_request(:post, "https://hooks.slack.com/services/test")
      .to_return(status: 200, body: "ok")

    post test_api_v1_channel_url(@channel.id), headers: auth_headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json.key?("success")
  end

  private

  def auth_headers
    {
      "Authorization" => "Bearer valid_token",
      "X-Project-ID" => @project.id
    }
  end
end
