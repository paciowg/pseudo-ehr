import { Controller } from "@hotwired/stimulus"
// TODO: When ApexCharts is managed locally, this should be changed back to:
// import ApexCharts from "apexcharts"
import "apexcharts"

// Connects to data-controller="graph"
export default class extends Controller {
  static targets = ["modal", "chart"]
  static values = { url: String }

  connect() {
    this.chart = null
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  async renderGraph(event) {
    const ids = event.currentTarget.dataset.ids
    if (!ids) {
      console.error("No observation IDs found on the button.")
      return
    }

    const url = `${this.urlValue}?ids=${ids}`

    try {
      const response = await fetch(url)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      const graphData = await response.json()

      this.chartTarget.innerHTML = "" // Clear previous chart
      this.modalTarget.classList.remove("hidden")

      const options = {
        series: graphData.series,
        chart: {
          height: 350,
          type: 'line',
        },
        markers: {
          size: 5
        },
        title: {
          text: graphData.title,
          align: 'left'
        },
        xaxis: {
          type: 'datetime',
          labels: {
            datetimeFormatter: {
              year: 'yyyy',
              month: 'MMM yyyy',
              day: 'dd MMM',
              hour: 'HH:mm'
            }
          }
        },
        yaxis: {
          title: {
            text: graphData.y_axis_label || 'Score'
          },
        },
        tooltip: {
          x: {
            format: 'dd MMM yyyy HH:mm'
          }
        }
      }

      const cutPoints = (graphData.cut_points || []).map((range) => ({
        ...range,
        limit: range.limit == null ? Infinity : range.limit
      }))

      if (cutPoints.length > 0) {
        const yMin = graphData.y_min !== null ? graphData.y_min : 0
        const yMax = graphData.y_max !== null ? graphData.y_max : 100

        options.annotations = { yaxis: [] }

        let previousLimit = yMin

        cutPoints.forEach((range) => {
          const limit = range.limit === Infinity ? yMax : range.limit
          const y1 = Math.max(previousLimit, yMin)
          const y2 = Math.min(limit, yMax)

          if (y1 < y2) {
            options.annotations.yaxis.push({
              y: y1,
              y2: y2,
              fillColor: range.color,
              opacity: 0.4,
            })
          }

          previousLimit = limit
        })

        options.tooltip.y = {
          formatter: (value) => {
            const range = cutPoints.find((r) => value < r.limit)
            const label = range ? range.label : ""
            return `${value} (${label})`
          }
        }
      }

      if (graphData.y_min != null) {
        options.yaxis.min = graphData.y_min
      }
      if (graphData.y_max != null) {
        options.yaxis.max = graphData.y_max
      }

      // TODO: When ApexCharts is managed locally, this should be changed back to:
      // this.chart = new ApexCharts(this.chartTarget, options)
      this.chart = new window.ApexCharts(this.chartTarget, options)
      this.chart.render()

    } catch (error) {
      console.error("Could not fetch or render graph data:", error)
    }
  }

  closeModal() {
    this.modalTarget.classList.add("hidden")
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }
}
