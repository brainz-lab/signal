# frozen_string_literal: true

module Api
  module V1
    # Receives browser custom events from brainzlab-js SDK
    class BrowserController < BaseController
      skip_before_action :authenticate!, only: [:preflight, :create]
      skip_before_action :set_project, only: [:preflight, :create], raise: false
      before_action :set_cors_headers
      before_action :find_project_from_token, only: [:create]
      before_action :validate_origin!, only: [:create]

      # OPTIONS /api/v1/browser (CORS preflight)
      def preflight
        head :ok
      end

      # POST /api/v1/browser
      # Receives browser custom events from brainzlab-js SDK
      def create
        events = params[:events] || []
        context = params[:context] || {}
        accepted = 0

        unless @project
          render json: { error: "Project not found" }, status: :not_found
          return
        end

        events.each do |event|
          next unless event[:type] == "custom"

          process_custom_event(event, context)
          accepted += 1
        end

        render json: {
          status: "ok",
          session_id: request.headers["X-BrainzLab-Session"],
          accepted: accepted
        }
      rescue StandardError => e
        Rails.logger.error("[BrowserController] Error: #{e.message}")
        render json: { error: "Failed to process events" }, status: :unprocessable_entity
      end

      private

      def process_custom_event(event, context)
        data = event[:data] || {}
        trace_ctx = extract_trace_context

        event_data = {
          name: data[:name],
          properties: data[:properties],
          source: "browser",
          url: event[:url],
          user_agent: event[:userAgent],
          session_id: event[:sessionId]
        }

        # Include trace context for correlation with server-side traces
        if trace_ctx
          event_data[:trace_id] = trace_ctx[:trace_id]
          event_data[:parent_span_id] = trace_ctx[:parent_span_id] || trace_ctx[:span_id]
        end

        # Also include trace info from event itself if present
        if event[:traceId]
          event_data[:trace_id] ||= event[:traceId]
          event_data[:browser_span_id] = event[:spanId]
          event_data[:parent_span_id] ||= event[:parentSpanId]
        end

        # Log the custom event for now
        Rails.logger.info("[BrowserController] Custom event: #{data[:name]} for project #{@project.id} - #{event_data.to_json}")
      rescue StandardError => e
        Rails.logger.warn("[BrowserController] Failed to process custom event: #{e.message}")
      end

      def find_project_from_token
        token = extract_browser_token
        return unless token

        # Prefer ingest_key for browser access (write-only, safe for browser exposure)
        if token.start_with?("sig_ingest_")
          @project = Project.find_by("settings->>'ingest_key' = ?", token)
        elsif token.start_with?("sig_api_")
          # Accept api_key but log warning - should use ingest_key for browser
          @project = Project.find_by("settings->>'api_key' = ?", token)
          Rails.logger.warn("[BrowserController] API key used for browser endpoint - consider using ingest_key")
        elsif token.start_with?("sig_")
          # Legacy key format - try both
          @project = Project.find_by("settings->>'ingest_key' = ?", token) ||
                     Project.find_by("settings->>'api_key' = ?", token)
        else
          # Try to find by project_id from context
          project_id = params.dig(:context, :projectId)
          @project = Project.find_by(platform_project_id: project_id) if project_id
        end
      end

      def validate_origin!
        return unless @project

        # Skip validation in development
        return if Rails.env.development?

        # Skip validation for localhost origins
        origin = request.headers["Origin"]
        return if origin_is_localhost?(origin)

        # Validate against allowed_origins
        unless @project.origin_allowed?(origin)
          render json: { error: "Origin not allowed" }, status: :forbidden
        end
      end

      def origin_is_localhost?(origin)
        return false if origin.blank?
        uri = URI.parse(origin)
        uri.host == "localhost" || uri.host == "127.0.0.1" || uri.host&.end_with?(".localhost")
      rescue URI::InvalidURIError
        false
      end

      def extract_browser_token
        auth_header = request.headers["Authorization"]
        return auth_header.sub(/^Bearer\s+/, "") if auth_header&.start_with?("Bearer ")
        request.headers["X-API-Key"]
      end

      def set_cors_headers
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-API-Key, X-BrainzLab-Session, traceparent, tracestate"
        response.headers["Access-Control-Max-Age"] = "86400"
      end

      # Extract trace context from request (W3C Trace Context format or body)
      def extract_trace_context
        # Try traceparent header first (W3C Trace Context)
        traceparent = request.headers["traceparent"] || request.headers["HTTP_TRACEPARENT"]
        if traceparent
          parts = traceparent.split("-")
          if parts.length >= 4
            return {
              trace_id: parts[1],
              span_id: parts[2],
              sampled: (parts[3].to_i(16) & 0x01) == 1
            }
          end
        end

        # Fallback to body context
        context = params[:context] || {}
        if context[:traceId]
          return {
            trace_id: context[:traceId],
            parent_span_id: context[:parentSpanId],
            sampled: true
          }
        end

        nil
      end
    end
  end
end
