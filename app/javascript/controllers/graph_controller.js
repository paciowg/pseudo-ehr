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
        title: {
          text: graphData.title,
          align: 'left'
        },
        xaxis: {
          type: 'datetime',
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
