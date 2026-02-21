import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"
Chart.register(...registerables)

export default class extends Controller {
  static values = {
    type: { type: String, default: "line" },
    data: { type: String, default: "[]" },
    labels: { type: String, default: "[]" },
    metric: { type: String, default: "" },
    maxPoints: { type: Number, default: 100 },
    colors: { type: String, default: "" }
  }

  connect() {
    this.isDark = document.documentElement.classList.contains("dark")
    this.createChart()
    this.handleThemeChange = this.handleThemeChange.bind(this)
    document.addEventListener("dark-mode:changed", this.handleThemeChange)
    document.addEventListener("chart:update", this.handleChartUpdate.bind(this))
  }

  disconnect() {
    document.removeEventListener("dark-mode:changed", this.handleThemeChange)
    document.removeEventListener("chart:update", this.handleChartUpdate.bind(this))
    if (this.chart) this.chart.destroy()
  }

  createChart() {
    const ctx = this.element.getContext("2d")
    const config = this.buildConfig()
    this.chart = new Chart(ctx, config)
  }

  buildConfig() {
    const type = this.typeValue
    const textColor = this.isDark ? "rgba(255,255,255,0.7)" : "rgba(0,0,0,0.6)"
    const gridColor = this.isDark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.06)"

    if (type === "doughnut") {
      return this.buildDoughnutConfig(textColor)
    }

    return this.buildLineBarConfig(type, textColor, gridColor)
  }

  buildDoughnutConfig(textColor) {
    const data = JSON.parse(this.dataValue)
    const labels = JSON.parse(this.labelsValue)
    const colors = this.colorsValue ? JSON.parse(this.colorsValue) : [
      "rgba(239, 68, 68, 0.8)",
      "rgba(245, 158, 11, 0.8)",
      "rgba(59, 130, 246, 0.8)"
    ]

    return {
      type: "doughnut",
      data: {
        labels: labels,
        datasets: [{
          data: data,
          backgroundColor: colors,
          borderWidth: 0,
          hoverOffset: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "70%",
        plugins: {
          legend: {
            position: "bottom",
            labels: { color: textColor, padding: 16, usePointStyle: true, pointStyleWidth: 8, font: { size: 12 } }
          }
        }
      }
    }
  }

  buildLineBarConfig(type, textColor, gridColor) {
    const data = JSON.parse(this.dataValue)

    return {
      type: type,
      data: {
        datasets: [{
          data: data.map(d => d.y),
          borderColor: "rgba(217, 119, 6, 0.8)",
          backgroundColor: type === "bar" ? "rgba(217, 119, 6, 0.3)" : "rgba(217, 119, 6, 0.1)",
          borderWidth: 2,
          fill: type === "line",
          tension: 0.3,
          pointRadius: type === "line" ? 0 : undefined,
          pointHoverRadius: type === "line" ? 4 : undefined,
          barThickness: type === "bar" ? 24 : undefined
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        scales: {
          x: {
            type: "category",
            labels: data.map(d => {
              const date = new Date(d.x)
              return date.toLocaleDateString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })
            }),
            grid: { display: false },
            ticks: { color: textColor, font: { size: 11 }, maxTicksLimit: 8, maxRotation: 0 }
          },
          y: {
            beginAtZero: true,
            grid: { color: gridColor },
            ticks: { color: textColor, font: { size: 11 }, precision: 0 }
          }
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: this.isDark ? "rgba(30,30,30,0.95)" : "rgba(255,255,255,0.95)",
            titleColor: this.isDark ? "#fff" : "#111",
            bodyColor: this.isDark ? "rgba(255,255,255,0.8)" : "rgba(0,0,0,0.7)",
            borderColor: this.isDark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)",
            borderWidth: 1,
            padding: 10,
            cornerRadius: 8
          }
        }
      }
    }
  }

  handleThemeChange() {
    this.isDark = document.documentElement.classList.contains("dark")
    if (this.chart) {
      this.chart.destroy()
      this.createChart()
    }
  }

  handleChartUpdate(event) {
    if (!this.chart || event.detail.metric !== this.metricValue) return

    const dataset = this.chart.data.datasets[0]
    if (event.detail.point) {
      dataset.data.push(event.detail.point)
      if (dataset.data.length > this.maxPointsValue) dataset.data.shift()
    } else if (event.detail.data) {
      if (this.typeValue === "doughnut") {
        this.chart.data.datasets[0].data = event.detail.data
      } else {
        dataset.data = event.detail.data
      }
    }
    this.chart.update("none")
  }
}
