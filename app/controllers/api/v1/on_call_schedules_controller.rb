module Api
  module V1
    class OnCallSchedulesController < BaseController
      before_action :set_schedule, only: [:show, :update, :destroy, :current]

      def index
        schedules = OnCallSchedule.for_project(@project_id).order(:name)
        render json: {
          on_call_schedules: schedules.map { |s| serialize_schedule(s) }
        }
      end

      def show
        render json: serialize_schedule(@schedule, full: true)
      end

      def create
        schedule = OnCallSchedule.new(schedule_params)
        schedule.project_id = @project_id

        if schedule.save
          render json: serialize_schedule(schedule), status: :created
        else
          render json: { errors: schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @schedule.update(schedule_params)
          render json: serialize_schedule(@schedule)
        else
          render json: { errors: @schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @schedule.destroy!
        head :no_content
      end

      def current
        render json: {
          on_call: @schedule.current_on_call_user,
          shift_start: @schedule.current_shift_start,
          shift_end: @schedule.current_shift_end
        }
      end

      private

      def set_schedule
        @schedule = OnCallSchedule.for_project(@project_id).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def schedule_params
        params.require(:on_call_schedule).permit(
          :name, :timezone, :schedule_type, :rotation_type, :rotation_start, :enabled,
          weekly_schedule: {}, members: []
        )
      end

      def serialize_schedule(schedule, full: false)
        data = {
          id: schedule.id,
          name: schedule.name,
          slug: schedule.slug,
          schedule_type: schedule.schedule_type,
          timezone: schedule.timezone,
          enabled: schedule.enabled,
          current_on_call: schedule.current_on_call
        }

        if full
          data.merge!(
            weekly_schedule: schedule.weekly_schedule,
            members: schedule.members,
            rotation_type: schedule.rotation_type,
            rotation_start: schedule.rotation_start,
            current_shift_start: schedule.current_shift_start,
            current_shift_end: schedule.current_shift_end
          )
        end

        data
      end
    end
  end
end
