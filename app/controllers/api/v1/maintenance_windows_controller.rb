module Api
  module V1
    class MaintenanceWindowsController < BaseController
      before_action :set_window, only: [ :show, :update, :destroy ]

      def index
        windows = MaintenanceWindow.for_project(@project_id).order(starts_at: :desc)
        windows = windows.active if params[:active] == "true"
        windows = windows.current if params[:current] == "true"

        render json: {
          maintenance_windows: windows.map { |w| serialize_window(w) }
        }
      end

      def show
        render json: serialize_window(@window, full: true)
      end

      def create
        window = MaintenanceWindow.new(window_params)
        window.project_id = @project_id
        window.created_by = params[:created_by] || "API"

        if window.save
          render json: serialize_window(window), status: :created
        else
          render json: { errors: window.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @window.update(window_params)
          render json: serialize_window(@window)
        else
          render json: { errors: @window.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @window.destroy!
        head :no_content
      end

      private

      def set_window
        @window = MaintenanceWindow.for_project(@project_id).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def window_params
        params.require(:maintenance_window).permit(
          :name, :description, :starts_at, :ends_at, :recurring, :recurrence_rule, :active,
          rule_ids: [], services: []
        )
      end

      def serialize_window(window, full: false)
        data = {
          id: window.id,
          name: window.name,
          starts_at: window.starts_at,
          ends_at: window.ends_at,
          active: window.active,
          currently_active: window.currently_active?,
          created_by: window.created_by
        }

        if full
          data.merge!(
            description: window.description,
            rule_ids: window.rule_ids,
            services: window.services,
            recurring: window.recurring,
            recurrence_rule: window.recurrence_rule
          )
        end

        data
      end
    end
  end
end
