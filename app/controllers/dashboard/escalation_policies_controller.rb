module Dashboard
  class EscalationPoliciesController < BaseController
    before_action :set_escalation_policy, only: [ :show, :edit, :update, :destroy ]

    def index
      @escalation_policies = EscalationPolicy.for_project(@project.id).order(created_at: :desc)
      @total_count = @escalation_policies.count
      @enabled_count = @escalation_policies.enabled.count
    end

    def show
      @linked_rules = AlertRule.where(escalation_policy_id: @escalation_policy.id).order(:name)
    end

    def new
      @escalation_policy = EscalationPolicy.new
      @channels = NotificationChannel.for_project(@project.id).enabled.order(:name)
    end

    def create
      @escalation_policy = EscalationPolicy.new(escalation_policy_params)
      @escalation_policy.project_id = @project.id

      if @escalation_policy.save
        redirect_to dashboard_project_escalation_policy_path(@project, @escalation_policy), notice: "Escalation policy created."
      else
        @channels = NotificationChannel.for_project(@project.id).enabled.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @channels = NotificationChannel.for_project(@project.id).enabled.order(:name)
    end

    def update
      if @escalation_policy.update(escalation_policy_params)
        redirect_to dashboard_project_escalation_policy_path(@project, @escalation_policy), notice: "Escalation policy updated."
      else
        @channels = NotificationChannel.for_project(@project.id).enabled.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @escalation_policy.destroy
      redirect_to dashboard_project_escalation_policies_path(@project), notice: "Escalation policy deleted."
    end

    private

    def set_escalation_policy
      @escalation_policy = EscalationPolicy.find(params[:id])
    end

    def escalation_policy_params
      params.require(:escalation_policy).permit(:name, :description, :enabled, :repeat, :repeat_after_minutes, :max_repeats, steps: [ :channel_id, :delay_minutes ])
    end
  end
end
