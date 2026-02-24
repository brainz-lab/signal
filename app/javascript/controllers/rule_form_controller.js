import { Controller } from "@hotwired/stimulus"

const SOURCE_CATALOG = {
  flux: {
    label: "Flux (Metrics)",
    color: "#3b82f6",
    nameLabel: "Metric Name",
    namePlaceholder: "e.g. http_requests_total",
    description: "Query numeric metrics and counters from Flux.",
    metrics: [
      { name: "http_requests_total", desc: "Total HTTP requests", agg: "sum" },
      { name: "http_request_duration_ms", desc: "Request latency (ms)", agg: "avg" },
      { name: "cpu_usage_percent", desc: "CPU utilization %", agg: "avg" },
      { name: "memory_usage_bytes", desc: "Memory usage", agg: "avg" },
      { name: "active_connections", desc: "Open connections", agg: "avg" },
      { name: "queue_depth", desc: "Job queue size", agg: "avg" },
      { name: "error_count", desc: "Error occurrences", agg: "sum" },
      { name: "disk_usage_percent", desc: "Disk usage %", agg: "avg" },
      { name: "cache_hit_ratio", desc: "Cache hit rate", agg: "avg" },
      { name: "custom_metric", desc: "Your custom metric", agg: "avg" }
    ],
    aggregations: ["avg", "sum", "count", "min", "max", "p50", "p95", "p99"],
    queryHint: "Filter by labels: {\"host\": \"web-1\", \"env\": \"production\"}",
    groupByHint: "Group by label keys: host, env, region, service"
  },
  pulse: {
    label: "Pulse (APM)",
    color: "#8b5cf6",
    nameLabel: "Trace Metric",
    namePlaceholder: "e.g. response_time",
    description: "Query APM traces and performance metrics from Pulse.",
    metrics: [
      { name: "response_time", desc: "Avg response time (ms)", agg: "avg" },
      { name: "throughput", desc: "Requests per second", agg: "sum" },
      { name: "error_rate", desc: "Error percentage", agg: "avg" },
      { name: "apdex", desc: "Apdex score (0-1)", agg: "avg" },
      { name: "db_query_time", desc: "Database query time (ms)", agg: "avg" },
      { name: "external_call_time", desc: "External API call time (ms)", agg: "avg" },
      { name: "transaction_count", desc: "Transaction volume", agg: "sum" },
      { name: "slow_transactions", desc: "Transactions > threshold", agg: "count" }
    ],
    aggregations: ["avg", "sum", "count", "p50", "p95", "p99"],
    queryHint: "Filter by trace attributes: {\"service\": \"api\", \"endpoint\": \"/users\"}",
    groupByHint: "Group by: service, endpoint, method, status_code"
  },
  reflex: {
    label: "Reflex (Errors)",
    color: "#ef4444",
    nameLabel: "Error Type",
    namePlaceholder: "e.g. NoMethodError",
    description: "Query error rates and exception counts from Reflex.",
    metrics: [
      { name: "all", desc: "All errors combined", agg: "count" },
      { name: "NoMethodError", desc: "Ruby NoMethodError", agg: "count" },
      { name: "ActiveRecord::RecordNotFound", desc: "Record not found", agg: "count" },
      { name: "ActionController::RoutingError", desc: "404 routing errors", agg: "count" },
      { name: "Timeout::Error", desc: "Timeout exceptions", agg: "count" },
      { name: "Net::ReadTimeout", desc: "Network read timeouts", agg: "count" },
      { name: "Redis::ConnectionError", desc: "Redis connection failures", agg: "count" },
      { name: "unhandled", desc: "Unhandled exceptions", agg: "count" }
    ],
    aggregations: ["count", "sum", "avg"],
    queryHint: "Filter by error context: {\"controller\": \"UsersController\", \"action\": \"show\"}",
    groupByHint: "Group by: error_class, controller, action, environment"
  },
  recall: {
    label: "Recall (Logs)",
    color: "#10b981",
    nameLabel: "Log Level",
    namePlaceholder: "e.g. error",
    description: "Query log volume and patterns from Recall.",
    metrics: [
      { name: "error", desc: "Error log entries", agg: "count" },
      { name: "warn", desc: "Warning log entries", agg: "count" },
      { name: "fatal", desc: "Fatal/critical logs", agg: "count" },
      { name: "info", desc: "Info log entries", agg: "count" },
      { name: "debug", desc: "Debug log entries", agg: "count" },
      { name: "all", desc: "All log levels", agg: "count" }
    ],
    aggregations: ["count", "sum"],
    queryHint: "Filter by log fields: {\"service\": \"worker\", \"message_contains\": \"timeout\"}",
    groupByHint: "Group by: service, level, host, tag"
  }
}

export default class extends Controller {
  static targets = [
    "sourceSelect", "sourceName", "sourceNameLabel",
    "sourceHelp", "metricSuggestions", "aggregationSelect",
    "queryInput", "groupByInput",
    "ruleTypeSelect", "thresholdFields", "anomalyFields", "absenceFields",
    "conditionPreview",
    "queryHint", "groupByHint"
  ]

  connect() {
    this.updateSourceHelp()
    this.updateRuleTypeFields()
    this.updateConditionPreview()
  }

  // Called when source dropdown changes
  sourceChanged() {
    this.updateSourceHelp()
    this.updateConditionPreview()
  }

  // Called when rule type dropdown changes
  ruleTypeChanged() {
    this.updateRuleTypeFields()
    this.updateConditionPreview()
  }

  // Called on any form field change
  fieldChanged() {
    this.updateConditionPreview()
  }

  // Pick a suggested metric
  pickMetric(event) {
    event.preventDefault()
    const name = event.currentTarget.dataset.metric
    const agg = event.currentTarget.dataset.agg
    if (this.hasSourceNameTarget) this.sourceNameTarget.value = name
    if (this.hasAggregationSelectTarget && agg) this.aggregationSelectTarget.value = agg
    this.updateConditionPreview()
  }

  updateSourceHelp() {
    const source = this.sourceSelectTarget.value
    const catalog = SOURCE_CATALOG[source]
    if (!catalog) return

    // Update name label
    if (this.hasSourceNameLabelTarget) {
      this.sourceNameLabelTarget.textContent = catalog.nameLabel
    }

    // Update placeholder
    if (this.hasSourceNameTarget) {
      this.sourceNameTarget.placeholder = catalog.namePlaceholder
    }

    // Update help panel
    if (this.hasSourceHelpTarget) {
      this.sourceHelpTarget.innerHTML = this.buildHelpPanel(catalog)
      this.sourceHelpTarget.classList.remove("hidden")
    }

    // Update metric suggestions
    if (this.hasMetricSuggestionsTarget) {
      this.metricSuggestionsTarget.innerHTML = catalog.metrics.map(m =>
        `<button type="button" data-action="rule-form#pickMetric" data-metric="${this.escapeAttr(m.name)}" data-agg="${m.agg}"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-[12px] font-medium transition-all cursor-pointer dm-surface-hover dm-border" style="border: 1px solid var(--color-border-subtle);">
          <span class="w-1.5 h-1.5 rounded-full" style="background: ${catalog.color};"></span>
          <span class="dm-text">${this.escapeHtml(m.name)}</span>
          <span class="dm-text-muted text-[10px]">${this.escapeHtml(m.desc)}</span>
        </button>`
      ).join("")
    }

    // Update aggregation options
    if (this.hasAggregationSelectTarget) {
      const currentVal = this.aggregationSelectTarget.value
      this.aggregationSelectTarget.innerHTML = catalog.aggregations.map(a =>
        `<option value="${a}" ${a === currentVal ? 'selected' : ''}>${a.toUpperCase()}</option>`
      ).join("")
    }

    // Update hints
    if (this.hasQueryHintTarget) this.queryHintTarget.textContent = catalog.queryHint
    if (this.hasGroupByHintTarget) this.groupByHintTarget.textContent = catalog.groupByHint
  }

  updateRuleTypeFields() {
    const ruleType = this.ruleTypeSelectTarget.value

    // Toggle field visibility
    if (this.hasThresholdFieldsTarget) {
      this.thresholdFieldsTarget.classList.toggle("hidden", ruleType !== "threshold")
    }
    if (this.hasAnomalyFieldsTarget) {
      this.anomalyFieldsTarget.classList.toggle("hidden", ruleType !== "anomaly")
    }
    if (this.hasAbsenceFieldsTarget) {
      this.absenceFieldsTarget.classList.toggle("hidden", ruleType !== "absence")
    }
  }

  updateConditionPreview() {
    if (!this.hasConditionPreviewTarget) return

    const source = this.sourceSelectTarget.value
    const sourceName = this.hasSourceNameTarget ? this.sourceNameTarget.value : ""
    const ruleType = this.ruleTypeSelectTarget.value
    const catalog = SOURCE_CATALOG[source]

    let preview = ""
    const nameDisplay = sourceName || catalog?.namePlaceholder?.replace("e.g. ", "") || "metric"

    if (ruleType === "threshold") {
      const agg = this.hasAggregationSelectTarget ? this.aggregationSelectTarget.value : "avg"
      const op = this.element.querySelector("[name*='operator']")?.value || "gt"
      const threshold = this.element.querySelector("[name*='threshold']")?.value || "?"
      const window = this.element.querySelector("[name*='window']")?.value || "5m"
      const opSymbol = { gt: ">", gte: ">=", lt: "<", lte: "<=", eq: "=", neq: "!=" }[op] || ">"

      preview = `<span class="font-semibold">${agg}</span>(<span style="color: ${catalog?.color || '#d97706'}">${this.escapeHtml(nameDisplay)}</span>) <span class="font-semibold">${opSymbol} ${this.escapeHtml(threshold)}</span> <span class="dm-text-muted">over ${window}</span>`
    } else if (ruleType === "anomaly") {
      const sensitivity = this.element.querySelector("[name*='sensitivity']")?.value || "5"
      preview = `anomaly in <span style="color: ${catalog?.color || '#d97706'}">${this.escapeHtml(nameDisplay)}</span> <span class="dm-text-muted">sensitivity: ${sensitivity}/10</span>`
    } else if (ruleType === "absence") {
      const interval = this.element.querySelector("[name*='expected_interval']")?.value || "5m"
      preview = `no data for <span style="color: ${catalog?.color || '#d97706'}">${this.escapeHtml(nameDisplay)}</span> <span class="dm-text-muted">expected every ${interval}</span>`
    }

    this.conditionPreviewTarget.innerHTML = preview || '<span class="dm-text-muted">Configure your rule to see a preview</span>'
  }

  buildHelpPanel(catalog) {
    return `
      <div class="flex items-center gap-2 mb-2">
        <span class="w-2 h-2 rounded-full" style="background: ${catalog.color};"></span>
        <span class="text-[13px] font-semibold dm-text">${catalog.label}</span>
      </div>
      <p class="text-[12px] dm-text-muted mb-2">${catalog.description}</p>
    `
  }

  escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str || ""
    return div.innerHTML
  }

  escapeAttr(str) {
    return (str || "").replace(/"/g, "&quot;").replace(/'/g, "&#39;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }
}
