import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="graph"
export default class extends Controller {
  static values = { url: String }

  async fetchData(event) {
    const ids = event.currentTarget.dataset.ids
    if (!ids) {
      console.error("No observation IDs found on the button.")
      return
    }

    const url = `${this.urlValue}?ids=${ids}`

    try {
      const response = await fetch(url)
      if (!response.ok) {
        const errorText = await response.text()
        throw new Error(`HTTP error! status: ${response.status}, message: ${errorText}`)
      }
      const data = await response.json()
      console.log("Graph Data:", data)
    } catch (error) {
      console.error("Could not fetch graph data:", error)
    }
  }
}
