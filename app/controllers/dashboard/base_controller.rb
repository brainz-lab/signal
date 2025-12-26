module Dashboard
  class BaseController < ActionController::Base
    layout 'dashboard'

    # Include necessary modules for full controller functionality
    include ActionController::Flash
    protect_from_forgery with: :exception

    # Make URL helpers available in views
    helper :all
    include Rails.application.routes.url_helpers

    def default_url_options
      { host: request.host, port: request.port }
    end

    before_action :authenticate!
    before_action :set_project

    helper_method :current_project

    private

    def authenticate!
      # In development, skip authentication entirely
      return if Rails.env.development?

      raw_key = extract_api_key
      return redirect_to_auth if raw_key.blank?

      # Validate with Platform service
      if defined?(PlatformClient)
        @api_key_info = PlatformClient.validate_key(raw_key)

        unless @api_key_info[:valid]
          session.delete(:api_key)
          return redirect_to_auth
        end
      else
        # If PlatformClient isn't available, accept any key
        @api_key_info = { valid: true }
      end

      # Store in session for subsequent requests
      session[:api_key] = raw_key unless session[:api_key]
    end

    def set_project
      # For nested routes, use :project_id
      # For member routes on projects, use :id
      project_id = params[:project_id] || (controller_name == 'projects' ? params[:id] : nil)
      return unless project_id.present?

      @project = Project.find_by(id: project_id)
      return unless @project

      # Skip authorization check in development
      return if Rails.env.development?

      # Verify the project matches the API key's project
      if @api_key_info && @api_key_info[:project_id] != @project.platform_project_id
        redirect_to dashboard_root_path, alert: 'Project access denied'
      end
    end

    def current_project
      @project
    end

    def extract_api_key
      # Check session first, then params
      session[:api_key] || params[:api_key]
    end

    def redirect_to_auth
      if params[:api_key].present?
        # Store in session and redirect without api_key in URL
        session[:api_key] = params[:api_key]
        redirect_to request.path
      else
        # Show auth required page or redirect to projects
        redirect_to dashboard_root_path, alert: 'Authentication required'
      end
    end
  end
end
