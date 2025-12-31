module Dashboard
  class RulesController < BaseController
    def index
      @rules = @project.alert_rules.order(created_at: :desc)

      # Filter by source
      if params[:source].present?
        @rules = @rules.where(source: params[:source])
      end

      # Filter by enabled
      if params[:enabled].present?
        @rules = @rules.where(enabled: params[:enabled] == "true")
      end

      @rules = @rules.limit(100)

      # Stats
      @total_count = @project.alert_rules.count
      @enabled_count = @project.alert_rules.where(enabled: true).count
      @muted_count = @project.alert_rules.where(muted: true).count
    end

    def show
      @rule = @project.alert_rules.find(params[:id])
      @recent_alerts = @rule.alerts.order(started_at: :desc).limit(10)
    end

    def new
      @rule = @project.alert_rules.new
    end

    def create
      @rule = @project.alert_rules.new(rule_params)
      if @rule.save
        redirect_to dashboard_project_rule_path(@project, @rule), notice: "Rule created successfully"
      else
        render :new
      end
    end

    def edit
      @rule = @project.alert_rules.find(params[:id])
    end

    def update
      @rule = @project.alert_rules.find(params[:id])
      if @rule.update(rule_params)
        redirect_to dashboard_project_rule_path(@project, @rule), notice: "Rule updated successfully"
      else
        render :edit
      end
    end

    def destroy
      @rule = @project.alert_rules.find(params[:id])
      @rule.destroy
      redirect_to dashboard_project_rules_path(@project), notice: "Rule deleted"
    end

    def mute
      @rule = @project.alert_rules.find(params[:id])
      duration = params[:duration] || "1h"
      until_time = case duration
      when "1h" then 1.hour.from_now
      when "4h" then 4.hours.from_now
      when "24h" then 24.hours.from_now
      when "7d" then 7.days.from_now
      else 1.hour.from_now
      end
      @rule.mute!(until_time: until_time, reason: params[:reason])
      redirect_to dashboard_project_rule_path(@project, @rule), notice: "Rule muted until #{until_time.strftime('%Y-%m-%d %H:%M')}"
    end

    def unmute
      @rule = @project.alert_rules.find(params[:id])
      @rule.unmute!
      redirect_to dashboard_project_rule_path(@project, @rule), notice: "Rule unmuted"
    end

    private

    def rule_params
      params.require(:alert_rule).permit(
        :name, :description, :source, :source_name, :source_type,
        :rule_type, :operator, :threshold, :aggregation, :window,
        :sensitivity, :baseline_window, :expected_interval,
        :severity, :evaluation_interval, :pending_period, :resolve_period,
        :enabled, :escalation_policy_id,
        notify_channels: [], group_by: [], labels: {}, annotations: {}
      )
    end
  end
end
