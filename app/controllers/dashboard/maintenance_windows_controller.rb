module Dashboard
  class MaintenanceWindowsController < BaseController
    before_action :set_maintenance_window, only: [:show, :edit, :update, :destroy]

    def index
      @maintenance_windows = MaintenanceWindow.for_project(@project.id).order(starts_at: :desc)
      @total_count = @maintenance_windows.count
      @active_count = @maintenance_windows.active.count
      @current_windows = @maintenance_windows.current
    end

    def show
      @affected_rules = AlertRule.where(id: @maintenance_window.rule_ids).order(:name)
    end

    def new
      @maintenance_window = MaintenanceWindow.new(
        starts_at: Time.current.beginning_of_hour + 1.hour,
        ends_at: Time.current.beginning_of_hour + 2.hours
      )
      @rules = AlertRule.for_project(@project.id).order(:name)
    end

    def create
      @maintenance_window = MaintenanceWindow.new(maintenance_window_params)
      @maintenance_window.project_id = @project.id

      if @maintenance_window.save
        redirect_to dashboard_project_maintenance_window_path(@project, @maintenance_window), notice: "Maintenance window created."
      else
        @rules = AlertRule.for_project(@project.id).order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @rules = AlertRule.for_project(@project.id).order(:name)
    end

    def update
      if @maintenance_window.update(maintenance_window_params)
        redirect_to dashboard_project_maintenance_window_path(@project, @maintenance_window), notice: "Maintenance window updated."
      else
        @rules = AlertRule.for_project(@project.id).order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @maintenance_window.destroy
      redirect_to dashboard_project_maintenance_windows_path(@project), notice: "Maintenance window deleted."
    end

    private

    def set_maintenance_window
      @maintenance_window = MaintenanceWindow.find(params[:id])
    end

    def maintenance_window_params
      params.require(:maintenance_window).permit(
        :name, :description, :starts_at, :ends_at, :active, :recurring, :recurrence_rule,
        rule_ids: [], services: []
      )
    end
  end
end
