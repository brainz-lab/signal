class HomeController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def index
    render json: {
      service: "signal",
      version: "1.0.0",
      status: "ok",
      endpoints: {
        health: "/up",
        api: "/api/v1",
        mcp: "/mcp/tools"
      }
    }
  end
end
