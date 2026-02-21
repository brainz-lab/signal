module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :project_id

    def connect
      self.project_id = find_project_id
    end

    private

    def find_project_id
      # In development, allow any connection
      return "dev" if Rails.env.development?

      # Extract project_id from session or reject
      session = request.session
      if session[:platform_project_id].present?
        session[:platform_project_id]
      else
        reject_unauthorized_connection
      end
    end
  end
end
