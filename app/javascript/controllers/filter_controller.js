import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "category", "noResults", "count", "domain", "graphButton"]

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
