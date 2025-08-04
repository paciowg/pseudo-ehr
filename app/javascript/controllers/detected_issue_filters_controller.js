import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="detected-issue-filters"
export default class extends Controller {
  static targets = ["issueRow", "issueDetails", "statusFilter", "severityFilter"]

  connect() {
    console.log("Detected Issue Filters controller connected")
  }

  filterByStatus() {
    const selectedStatus = this.statusFilterTarget.value
    this.filterIssues()
  }

  filterBySeverity() {
    const selectedSeverity = this.severityFilterTarget.value
    this.filterIssues()
  }

  filterIssues() {
    const selectedStatus = this.statusFilterTarget.value
    const selectedSeverity = this.severityFilterTarget.value

    this.issueRowTargets.forEach((row, index) => {
      const details = this.issueDetailsTargets[index]
      const rowStatus = row.dataset.status
      const rowSeverity = row.dataset.severity

      const statusMatch = selectedStatus === 'all' || rowStatus === selectedStatus
      const severityMatch = selectedSeverity === 'all' || rowSeverity === selectedSeverity

      if (statusMatch && severityMatch) {
        row.classList.remove('hidden')
      } else {
        row.classList.add('hidden')
        // Also hide details if they were expanded
        details.classList.add('hidden')
      }
    })
  }
}
