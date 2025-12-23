module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate!
      before_action :set_project

      private

      def authenticate!
        token = request.headers['Authorization']&.split(' ')&.last
        return render_unauthorized unless token

        @current_api_key = validate_api_key(token)
        render_unauthorized unless @current_api_key
      end

      def validate_api_key(token)
        # In production, validate against Platform service
        # For now, accept any token that looks valid
        return nil if token.blank?
        { token: token, project_id: extract_project_id(token) }
      end

      def extract_project_id(token)
        # Extract project_id from token or header
        request.headers['X-Project-ID'] || params[:project_id]
      end

      def set_project
        @project_id = @current_api_key[:project_id]
        render_unauthorized unless @project_id
      end

      def require_scope!(scope)
        # In production, validate scope against API key
        true
      end

      def render_unauthorized
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      def render_not_found
        render json: { error: 'Not found' }, status: :not_found
      end
    end
  end
end
