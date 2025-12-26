module Dashboard
  class IncidentsController < BaseController
    def index
      @incidents = @project.incidents.order(triggered_at: :desc)

      # Filter by status
      if params[:status].present?
        @incidents = @incidents.where(status: params[:status])
      end

      # Filter by severity
      if params[:severity].present?
        @incidents = @incidents.where(severity: params[:severity])
      end

      @incidents = @incidents.limit(100)

      # Stats
      @triggered_count = @project.incidents.where(status: 'triggered').count
      @acknowledged_count = @project.incidents.where(status: 'acknowledged').count
      @resolved_today = @project.incidents.where(status: 'resolved').where('resolved_at > ?', Time.current.beginning_of_day).count
    end

    def show
      @incident = @project.incidents.includes(:alerts).find(params[:id])
    end

    def acknowledge
      @incident = @project.incidents.find(params[:id])
      @incident.acknowledge!(by: 'Dashboard User')
      redirect_to dashboard_project_incident_path(@project, @incident), notice: 'Incident acknowledged'
    end

    def resolve
      @incident = @project.incidents.find(params[:id])
      @incident.resolve!(by: 'Dashboard User', note: params[:note])
      redirect_to dashboard_project_incident_path(@project, @incident), notice: 'Incident resolved'
    end
  end
end
