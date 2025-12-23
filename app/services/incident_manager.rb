class IncidentManager
  def initialize(alert)
    @alert = alert
    @rule = alert.alert_rule
    @project_id = alert.project_id
  end

  def fire!
    incident = find_or_create_incident
    @alert.update!(incident: incident)

    incident.add_timeline_event(
      type: 'alert_fired',
      message: "Alert fired: #{@rule.name}",
      data: { alert_id: @alert.id, value: @alert.current_value }
    )

    incident
  end

  def resolve!
    return unless @alert.incident

    @alert.incident.add_timeline_event(
      type: 'alert_resolved',
      message: "Alert resolved: #{@rule.name}",
      data: { alert_id: @alert.id }
    )

    # Check if all alerts for this incident are resolved
    if @alert.incident.alerts.firing.none?
      @alert.incident.resolve!
    end
  end

  private

  def find_or_create_incident
    # Find existing open incident for this rule
    existing = Incident.open.joins(:alerts).where(alerts: { alert_rule_id: @rule.id }).first
    return existing if existing

    # Create new incident
    Incident.create!(
      project_id: @project_id,
      title: @rule.name,
      summary: @rule.condition_description,
      severity: @rule.severity,
      status: 'triggered',
      triggered_at: Time.current,
      timeline: [{
        at: Time.current.iso8601,
        type: 'triggered',
        message: "Incident triggered by #{@rule.name}"
      }]
    )
  end
end
