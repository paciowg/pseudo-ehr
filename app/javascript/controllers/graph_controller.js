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

      // Add conditional annotations for score ranges
      // TODO: We should make these scores part of the overall application configuration and generalize the approach
      if (graphData.title === "PROMIS-10 Global Mental Health (GMH) score T-score (71969-0)") {
        const yMin = graphData.y_min !== null ? graphData.y_min : 0;
        const yMax = graphData.y_max !== null ? graphData.y_max : 100; // Default max for T-scores if not provided

        options.annotations = {
          yaxis: [{
            y: yMin,
            y2: 34,
            fillColor: 'rgba(255, 192, 192, 0.4)', // Subtle Red
            opacity: 0.4,
          }, {
            y: 34,
            y2: 42,
            fillColor: 'rgba(255, 255, 192, 0.4)', // Subtle Yellow
            opacity: 0.4,
          }, {
            y: 42,
            y2: yMax,
            fillColor: 'rgba(192, 255, 192, 0.4)', // Subtle Green
            opacity: 0.4,
          }]
        };
      } else if (graphData.title === "PROMIS-10 Global Physical Health (GPH) score T-score (71971-6)") {
        const yMin = graphData.y_min !== null ? graphData.y_min : 0;
        const yMax = graphData.y_max !== null ? graphData.y_max : 100; // Default max for T-scores if not provided

        options.annotations = {
          yaxis: [{
            y: yMin,
            y2: 36,
            fillColor: 'rgba(255, 192, 192, 0.4)', // Subtle Red
            opacity: 0.4,
          }, {
            y: 36,
            y2: 43,
            fillColor: 'rgba(255, 255, 192, 0.4)', // Subtle Yellow
            opacity: 0.4,
          }, {
            y: 43,
            y2: yMax,
            fillColor: 'rgba(192, 255, 192, 0.4)', // Subtle Green
            opacity: 0.4,
          }]
        };
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
