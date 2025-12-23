module Api
  module V1
    class EscalationPoliciesController < BaseController
      before_action :set_policy, only: [:show, :update, :destroy]

      def index
        policies = EscalationPolicy.for_project(@project_id).order(:name)
        render json: {
          escalation_policies: policies.map { |p| serialize_policy(p) }
        }
      end

      def show
        render json: serialize_policy(@policy, full: true)
      end

      def create
        policy = EscalationPolicy.new(policy_params)
        policy.project_id = @project_id

        if policy.save
          render json: serialize_policy(policy), status: :created
        else
          render json: { errors: policy.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @policy.update(policy_params)
          render json: serialize_policy(@policy)
        else
          render json: { errors: @policy.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @policy.destroy!
        head :no_content
      end

      private

      def set_policy
        @policy = EscalationPolicy.for_project(@project_id).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def policy_params
        params.require(:escalation_policy).permit(
          :name, :description, :repeat, :repeat_after_minutes, :max_repeats, :enabled,
          steps: []
        )
      end

      def serialize_policy(policy, full: false)
        data = {
          id: policy.id,
          name: policy.name,
          slug: policy.slug,
          enabled: policy.enabled,
          steps_count: policy.steps.count,
          rules_count: policy.alert_rules.count
        }

        if full
          data.merge!(
            description: policy.description,
            steps: policy.steps,
            repeat: policy.repeat,
            repeat_after_minutes: policy.repeat_after_minutes,
            max_repeats: policy.max_repeats
          )
        end

        data
      end
    end
  end
end
