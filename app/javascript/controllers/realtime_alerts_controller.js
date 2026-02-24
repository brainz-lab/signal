import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { projectId: String }
  static targets = [
    "firingCount", "pendingCount", "mtta", "mttr",
    "incidentsOpen", "notificationRate", "recentAlerts"
  ]

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "AlertsChannel", project_id: this.projectIdValue },
      {
        received: (data) => this.handleMessage(data)
      }
    )
  }

  disconnect() {
    if (this.subscription) this.subscription.unsubscribe()
    if (this.consumer) this.consumer.disconnect()
  }

  handleMessage(data) {
    if (data.type === "alert_update") {
      this.updateAlertCounters(data.alert)
      this.prependRecentAlert(data.alert)
      this.dispatchChartUpdate(data.alert)
    } else if (data.type === "incident_update") {
      this.updateIncidentCounter(data.incident)
    }
  }

  updateAlertCounters(alert) {
    // Re-fetch counters via a turbo frame or update optimistically
    if (this.hasFiringCountTarget) {
      const el = this.firingCountTarget
      const current = parseInt(el.textContent) || 0
      if (alert.state === "firing") el.textContent = current + 1
      else if (alert.state === "resolved" && current > 0) el.textContent = current - 1
    }

    if (this.hasPendingCountTarget) {
      const el = this.pendingCountTarget
      const current = parseInt(el.textContent) || 0
      if (alert.state === "pending") el.textContent = current + 1
      else if (alert.state === "firing" && current > 0) el.textContent = current - 1
    }
  }

  updateIncidentCounter(incident) {
    if (!this.hasIncidentsOpenTarget) return
    const el = this.incidentsOpenTarget
    const current = parseInt(el.textContent) || 0
    if (incident.status === "triggered") el.textContent = current + 1
    else if (incident.status === "resolved" && current > 0) el.textContent = current - 1
  }

  prependRecentAlert(alert) {
    if (!this.hasRecentAlertsTarget) return

    const container = this.recentAlertsTarget
    const stateColors = {
      firing: { bg: "bg-error", dot: "var(--color-error-dot)", badge: "dm-badge-error", label: "Firing" },
      pending: { bg: "bg-warning", dot: "var(--color-warning-dot)", badge: "dm-badge-warning", label: "Pending" },
      resolved: { bg: "bg-success", dot: "var(--color-success-dot)", badge: "dm-badge-success", label: "Resolved" }
    }
    const state = stateColors[alert.state] || stateColors.pending

    const row = document.createElement("div")
    row.className = "flex items-center justify-between px-4 py-3 border-t dm-border-light dm-fade-in-up"
    row.innerHTML = `
      <div class="flex items-center gap-3">
        <div class="w-8 h-8 rounded-lg flex items-center justify-center ${state.bg}">
          <span class="w-2 h-2 rounded-full ${alert.state === 'firing' ? 'animate-pulse' : ''}" style="background: ${state.dot};"></span>
        </div>
        <div>
          <p class="text-[13px] font-medium dm-text">${this.escapeHtml(alert.rule_name || "Alert")}</p>
          <p class="text-[11px] dm-text-muted">Just now</p>
        </div>
      </div>
      <span class="px-2 py-0.5 text-[10px] font-semibold uppercase rounded-full ${state.badge}">${state.label}</span>
    `

    // Insert after header row
    const firstChild = container.querySelector("[data-recent-row]")
    if (firstChild) {
      container.insertBefore(row, firstChild)
    } else {
      container.appendChild(row)
    }
    row.setAttribute("data-recent-row", "")

    // Limit to 10 items
    const rows = container.querySelectorAll("[data-recent-row]")
    if (rows.length > 10) rows[rows.length - 1].remove()
  }

  dispatchChartUpdate(alert) {
    // Update volume chart
    const now = new Date().toISOString()
    document.dispatchEvent(new CustomEvent("chart:update", {
      detail: { metric: "alert_volume", point: { x: now, y: 1 } }
    }))

    // Update severity chart
    const severity = alert.severity || "info"
    const severityMap = { critical: 0, warning: 1, info: 2 }
    const idx = severityMap[severity] ?? 2
    document.dispatchEvent(new CustomEvent("chart:update", {
      detail: { metric: "severity", idx: idx }
    }))
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
