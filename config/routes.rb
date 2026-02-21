Rails.application.routes.draw do
  # Root redirects to dashboard
  root to: redirect("/dashboard")

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # SSO from Platform
  get "sso/callback", to: "sso#callback"

  # Dashboard - new/edit routes defined explicitly to get standard Rails naming
  # These must be outside namespace to get new_dashboard_* naming instead of dashboard_new_*
  get "dashboard/projects/new", to: "dashboard/projects#new", as: :new_dashboard_project
  get "dashboard/projects/:id/edit", to: "dashboard/projects#edit", as: :edit_dashboard_project
  get "dashboard/projects/:project_id/rules/new", to: "dashboard/rules#new", as: :new_dashboard_project_rule
  get "dashboard/projects/:project_id/rules/:id/edit", to: "dashboard/rules#edit", as: :edit_dashboard_project_rule
  get "dashboard/projects/:project_id/channels/new", to: "dashboard/channels#new", as: :new_dashboard_project_channel
  get "dashboard/projects/:project_id/channels/:id/edit", to: "dashboard/channels#edit", as: :edit_dashboard_project_channel
  get "dashboard/projects/:project_id/escalation_policies/new", to: "dashboard/escalation_policies#new", as: :new_dashboard_project_escalation_policy
  get "dashboard/projects/:project_id/escalation_policies/:id/edit", to: "dashboard/escalation_policies#edit", as: :edit_dashboard_project_escalation_policy
  get "dashboard/projects/:project_id/on_call_schedules/new", to: "dashboard/on_call_schedules#new", as: :new_dashboard_project_on_call_schedule
  get "dashboard/projects/:project_id/on_call_schedules/:id/edit", to: "dashboard/on_call_schedules#edit", as: :edit_dashboard_project_on_call_schedule
  get "dashboard/projects/:project_id/maintenance_windows/new", to: "dashboard/maintenance_windows#new", as: :new_dashboard_project_maintenance_window
  get "dashboard/projects/:project_id/maintenance_windows/:id/edit", to: "dashboard/maintenance_windows#edit", as: :edit_dashboard_project_maintenance_window

  namespace :dashboard do
    root to: "projects#index"

    resources :projects, except: [ :new, :edit ] do
      get :overview, to: "overview#show"
      get :analytics, to: "analytics#show"
      get :setup, to: "projects#setup"
      get :mcp_setup, to: "projects#mcp_setup"
      post :regenerate_mcp_token, to: "projects#regenerate_mcp_token"
      resources :alerts, only: [ :index, :show ] do
        member do
          post :acknowledge
        end
      end
      resources :incidents, only: [ :index, :show ] do
        member do
          post :acknowledge
          post :resolve
        end
      end
      resources :saved_searches, only: [ :create, :destroy ]
      resources :exports, only: [ :create ]
      resources :rules, except: [ :new, :edit ] do
        member do
          post :mute
          post :unmute
        end
      end
      resources :channels, except: [ :new, :edit ] do
        member do
          post :test
        end
      end
      resources :escalation_policies, except: [ :new, :edit ]
      resources :on_call_schedules, except: [ :new, :edit ] do
        member do
          get :current
        end
      end
      resources :maintenance_windows, except: [ :new, :edit ]
    end
  end

  namespace :api do
    namespace :v1 do
      # Projects (provisioning)
      post "projects/provision", to: "projects#provision"
      get "projects/lookup", to: "projects#lookup"

      # Browser events (from brainzlab-js SDK)
      match "browser", to: "browser#preflight", via: :options
      post "browser", to: "browser#create"

      # Alerts
      resources :alerts, only: [ :index, :show ] do
        member do
          post :acknowledge
        end
      end
      post "alerts/trigger", to: "alerts#trigger"
      post "alerts/resolve", to: "alerts#resolve_by_name"

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
      resources :incidents, only: [ :index, :show ] do
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
    post "tools/:tool", to: "tools#execute"
    get "tools", to: "tools#list"
  end

  # Sidekiq Web UI (optional, for development)
  if defined?(Sidekiq)
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  end
end
