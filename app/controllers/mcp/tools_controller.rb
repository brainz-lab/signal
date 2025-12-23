module Mcp
  class ToolsController < ApplicationController
    before_action :authenticate!
    before_action :set_project

    def list
      tools = [
        {
          name: 'signal_list_alerts',
          description: Mcp::Tools::SignalListAlerts::DESCRIPTION,
          schema: Mcp::Tools::SignalListAlerts::SCHEMA
        },
        {
          name: 'signal_acknowledge',
          description: Mcp::Tools::SignalAcknowledge::DESCRIPTION,
          schema: Mcp::Tools::SignalAcknowledge::SCHEMA
        },
        {
          name: 'signal_create_rule',
          description: Mcp::Tools::SignalCreateRule::DESCRIPTION,
          schema: Mcp::Tools::SignalCreateRule::SCHEMA
        },
        {
          name: 'signal_mute',
          description: Mcp::Tools::SignalMute::DESCRIPTION,
          schema: Mcp::Tools::SignalMute::SCHEMA
        },
        {
          name: 'signal_incidents',
          description: Mcp::Tools::SignalIncidents::DESCRIPTION,
          schema: Mcp::Tools::SignalIncidents::SCHEMA
        }
      ]

      render json: { tools: tools }
    end

    def execute
      tool_class = tool_for(params[:tool])
      return render json: { error: 'Unknown tool' }, status: :not_found unless tool_class

      tool = tool_class.new(@project_id)
      result = tool.call(params.to_unsafe_h.symbolize_keys)

      render json: result
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def authenticate!
      token = request.headers['Authorization']&.split(' ')&.last
      return render json: { error: 'Unauthorized' }, status: :unauthorized unless token
    end

    def set_project
      @project_id = request.headers['X-Project-ID'] || params[:project_id]
      return render json: { error: 'Project ID required' }, status: :bad_request unless @project_id
    end

    def tool_for(name)
      case name
      when 'signal_list_alerts' then Mcp::Tools::SignalListAlerts
      when 'signal_acknowledge' then Mcp::Tools::SignalAcknowledge
      when 'signal_create_rule' then Mcp::Tools::SignalCreateRule
      when 'signal_mute' then Mcp::Tools::SignalMute
      when 'signal_incidents' then Mcp::Tools::SignalIncidents
      end
    end
  end
end
