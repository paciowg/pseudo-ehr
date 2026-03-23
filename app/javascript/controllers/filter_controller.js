import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "category", "noResults", "count", "domain", "graphButton", "trendList"]

  connect() {
    console.log("Filter controller connected")
  }

  filter() {
    const query = this.inputTarget.value.toLowerCase()
    let hasVisibleItems = false

    this.itemTargets.forEach((item) => {
      const code = item.dataset.code || ""
      const description = item.dataset.description || ""
      const isVisible = code.toLowerCase().includes(query) || description.toLowerCase().includes(query)
      item.classList.toggle("hidden", !isVisible)
      if (isVisible) {
        hasVisibleItems = true
      }
    })

    this.categoryTargets.forEach((category) => {
      const visibleItemsInCategory = category.querySelectorAll('[data-filter-target="item"]:not(.hidden)')
      const count = visibleItemsInCategory.length
      const hasVisibleItems = count > 0
      category.classList.toggle("hidden", !hasVisibleItems)

      const countElement = category.querySelector('[data-filter-target="count"]')
      if (countElement) {
        countElement.textContent = `(${count})`
      }
    })

    this.domainTargets.forEach((domain) => {
      const hasVisibleItems = domain.querySelectorAll('[data-filter-target="item"]:not(.hidden)').length > 0
      domain.classList.toggle("hidden", !hasVisibleItems)
    })

    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.toggle("hidden", hasVisibleItems)
    }

    this._updateGraphButtonState()
  }

  onViewChange(event) {
    if (event.target.value === "Observation Trends") {
      this.renderTrends()
    }
  }

  renderTrends() {
    if (!this.hasTrendListTarget) return

    this.trendListTarget.innerHTML = ""

    const groups = {}
    this.itemTargets.forEach(item => {
      const code = item.dataset.code
      if (!code) return
      if (!groups[code]) groups[code] = []
      groups[code].push(item)
    })

    let hasTrends = false

    Object.keys(groups).forEach(code => {
      const items = groups[code]
      
      const validItems = items.filter(item => {
        const status = item.dataset.status
        const hasDateTime = item.dataset.effectiveDateTime
        const hasValueQuantity = item.dataset.hasValueQuantity === 'true'
        const hasComponents = item.dataset.hasComponents === 'true'

        return (status === 'final' || status === 'amended') &&
          hasDateTime &&
          (hasValueQuantity || hasComponents)
      })

      if (validItems.length < 2) return

      hasTrends = true
      const description = validItems[0].dataset.description || code
      const count = validItems.length
      const ids = validItems.map(i => i.dataset.id).join(',')

      const el = document.createElement("div")
      el.className = "flex items-center justify-between p-4 bg-white border border-gray-200 rounded-lg shadow-sm hover:bg-gray-50 dark:bg-gray-800 dark:border-gray-700 dark:hover:bg-gray-700"
      el.innerHTML = `
        <div class="flex-1">
          <h3 class="text-lg font-medium text-gray-900 dark:text-white">${description}</h3>
          <p class="text-sm text-gray-500 dark:text-gray-400">${count} data points</p>
        </div>
        <div class="ml-4">
          <button type="button"
            class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            data-action="click->graph#renderGraph"
            data-ids="${ids}">
            Graph
          </button>
        </div>
      `
      this.trendListTarget.appendChild(el)
    })

    if (!hasTrends) {
       this.trendListTarget.innerHTML = `<div class="p-4 text-center text-gray-500 dark:text-gray-400">No trendable observations found.</div>`
    }
  }

  _updateGraphButtonState() {
    if (!this.hasGraphButtonTarget) { return }

    const visibleItems = this.itemTargets.filter(item => !item.classList.contains("hidden"))

    const criteriaMet = () => {
      if (visibleItems.length < 2) return false

      const firstItemCode = visibleItems[0].dataset.code
      if (!firstItemCode) return false

      return visibleItems.every(item => {
        const status = item.dataset.status
        const hasDateTime = item.dataset.effectiveDateTime
        const hasValueQuantity = item.dataset.hasValueQuantity === 'true'
        const hasComponents = item.dataset.hasComponents === 'true'

        return item.dataset.code === firstItemCode &&
          (status === 'final' || status === 'amended') &&
          hasDateTime &&
          (hasValueQuantity || hasComponents)
      })
    }

    if (criteriaMet()) {
      const visibleIds = visibleItems.map(item => item.dataset.id)
      this.graphButtonTarget.dataset.ids = visibleIds.join(',')
      this.graphButtonTarget.classList.remove("hidden")
    } else {
      this.graphButtonTarget.classList.add("hidden")
    }
  }
}
