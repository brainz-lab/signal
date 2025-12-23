Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Alerts
      resources :alerts, only: [:index, :show] do
        member do
          post :acknowledge
        end
      end
      post 'alerts/trigger', to: 'alerts#trigger'
      post 'alerts/resolve', to: 'alerts#resolve_by_name'

      # Alert Rules
      resources :rules do
        member do
          post :mute
          post :unmute
          post :test
        end
      end

      # Notification Channels
      resources :channels do
        member do
          post :test
        end
      end

      # Incidents
      resources :incidents, only: [:index, :show] do
        member do
          post :acknowledge
          post :resolve
        end
      end

      # Escalation Policies
      resources :escalation_policies

      # On-call Schedules
      resources :on_call_schedules do
        member do
          get :current
        end
      end

      # Maintenance Windows
      resources :maintenance_windows
    end
  end

  # MCP
  namespace :mcp do
    post 'tools/:tool', to: 'tools#execute'
    get 'tools', to: 'tools#list'
  end

  # Sidekiq Web UI (optional, for development)
  if defined?(Sidekiq)
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
end
