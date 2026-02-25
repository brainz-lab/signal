module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate!
      before_action :check_rate_limit!

      attr_reader :current_project

      private

      def check_rate_limit!
        return unless @current_project

        key = "signal:api_rate:#{@current_project.id}"
        path = request.path
        limit = path.include?("/browser") || path.include?("/trigger") ? 100 : 1000
        window = 1.minute

        count = Rails.cache.increment(key, 1, expires_in: window) || begin
          Rails.cache.write(key, 1, expires_in: window)
          1
        end

        if count > limit
          render json: { error: "Rate limit exceeded. Max #{limit} requests per minute." }, status: :too_many_requests
        end
      end

      def authenticate!
        raw_key = extract_api_key
        return render_unauthorized unless raw_key.present?

        # Check if it's a standalone sig_ API key (from auto-provisioning)
        if raw_key.start_with?("sig_api_", "sig_ingest_")
          @current_project = Project.find_by("settings->>'api_key' = ? OR settings->>'ingest_key' = ?", raw_key, raw_key)
          if @current_project
            @project_id = @current_project.id
            return
          end
        end

        # Try Platform key (sk_live_... or sk_test_...)
        if raw_key.start_with?("sk_live_", "sk_test_")
          @current_project = validate_with_platform(raw_key)
          if @current_project
            @project_id = @current_project.id
            return
          end
        end

        render_unauthorized
      end

      def validate_with_platform(key)
        result = PlatformClient.validate_key(key)
        return nil unless result.valid?

        # Create/sync local project from Platform
        PlatformClient.find_or_create_project(result, key)
      rescue StandardError => e
        Rails.logger.error "[BaseController] Platform validation error: #{e.message}"
        nil
      end

      def extract_api_key
        auth_header = request.headers["Authorization"]
        return auth_header.sub(/^Bearer\s+/, "") if auth_header&.start_with?("Bearer ")
        request.headers["X-API-Key"] || params[:api_key]
      end

      def render_unauthorized
        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def render_not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def track_usage!(count = 1)
        return unless @current_project

        PlatformClient.track_usage(
          project_id: @current_project.platform_project_id,
          product: "signal",
          metric: "alerts",
          count: count
        )
      end
    end
  end
end
