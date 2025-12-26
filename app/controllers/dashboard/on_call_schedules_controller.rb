module Dashboard
  class OnCallSchedulesController < BaseController
    before_action :set_schedule, only: [:show, :edit, :update, :destroy, :current]

    def index
      @schedules = OnCallSchedule.for_project(@project.id).order(created_at: :desc)
      @total_count = @schedules.count
      @enabled_count = @schedules.enabled.count
    end

    def show
    end

    def new
      @schedule = OnCallSchedule.new(schedule_type: 'weekly')
    end

    def create
      @schedule = OnCallSchedule.new(schedule_params)
      @schedule.project_id = @project.id

      if @schedule.save
        redirect_to dashboard_project_on_call_schedule_path(@project, @schedule), notice: "On-call schedule created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @schedule.update(schedule_params)
        redirect_to dashboard_project_on_call_schedule_path(@project, @schedule), notice: "On-call schedule updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @schedule.destroy
      redirect_to dashboard_project_on_call_schedules_path(@project), notice: "On-call schedule deleted."
    end

    def current
      render json: {
        on_call: @schedule.current_on_call,
        shift_start: @schedule.current_shift_start,
        shift_end: @schedule.current_shift_end
      }
    end

    private

    def set_schedule
      @schedule = OnCallSchedule.find(params[:id])
    end

    def schedule_params
      params.require(:on_call_schedule).permit(
        :name, :schedule_type, :timezone, :enabled, :rotation_type, :rotation_start,
        members: [], weekly_schedule: {}
      )
    end
  end
end
