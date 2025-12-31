module Api
  module V1
    class RulesController < BaseController
      before_action :set_rule, only: [ :show, :update, :destroy, :mute, :unmute, :test ]

      def index
        rules = AlertRule.for_project(@project_id).order(created_at: :desc)
        rules = rules.by_source(params[:source]) if params[:source].present?
        rules = rules.enabled if params[:enabled] == "true"

        render json: {
          rules: rules.map { |r| serialize_rule(r) }
        }
      end

      def show
        render json: serialize_rule(@rule, full: true)
      end

      def create
        rule = AlertRule.new(rule_params)
        rule.project_id = @project_id

        if rule.save
          render json: serialize_rule(rule), status: :created
        else
          render json: { errors: rule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @rule.update(rule_params)
          render json: serialize_rule(@rule)
        else
          render json: { errors: @rule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @rule.destroy!
        head :no_content
      end

      def mute
        @rule.mute!(
          until_time: params[:until] ? Time.parse(params[:until]) : nil,
          reason: params[:reason]
        )
        render json: serialize_rule(@rule)
      end

      def unmute
        @rule.unmute!
        render json: serialize_rule(@rule)
      end

      def test
        result = @rule.evaluate!
        render json: {
          rule: serialize_rule(@rule),
          result: result
        }
      end

      private

      def set_rule
        @rule = AlertRule.for_project(@project_id).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def rule_params
        params.require(:rule).permit(
          :name, :description, :source, :source_type, :source_name,
          :rule_type, :operator, :threshold, :aggregation, :window,
          :sensitivity, :baseline_window, :expected_interval,
          :composite_operator, :severity, :evaluation_interval,
          :pending_period, :resolve_period, :enabled, :escalation_policy_id,
          query: {}, group_by: [], notify_channels: [], labels: {},
          annotations: {}, composite_rules: []
        )
      end

      def serialize_rule(rule, full: false)
        data = {
          id: rule.id,
          name: rule.name,
          slug: rule.slug,
          source: rule.source,
          source_name: rule.source_name,
          rule_type: rule.rule_type,
          condition: rule.condition_description,
          severity: rule.severity,
          enabled: rule.enabled,
          muted: rule.muted?,
          last_state: rule.last_state,
          last_evaluated_at: rule.last_evaluated_at,
          firing_alerts_count: rule.alerts.firing.count
        }

        if full
          data.merge!(
            description: rule.description,
            operator: rule.operator,
            threshold: rule.threshold,
            aggregation: rule.aggregation,
            window: rule.window,
            query: rule.query,
            group_by: rule.group_by,
            notify_channels: rule.notify_channels,
            evaluation_interval: rule.evaluation_interval,
            pending_period: rule.pending_period,
            resolve_period: rule.resolve_period,
            labels: rule.labels,
            annotations: rule.annotations
          )
        end

        data
      end
    end
  end
end
