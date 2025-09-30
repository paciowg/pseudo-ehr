import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "category", "noResults", "count", "domain"]

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
  }
}
