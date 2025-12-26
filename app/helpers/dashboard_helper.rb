module DashboardHelper
  include Rails.application.routes.url_helpers

  def default_url_options
    { host: 'localhost', port: 4005 }
  end
end
