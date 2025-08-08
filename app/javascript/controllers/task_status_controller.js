import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { taskId: String }
  static targets = ["status", "message", "lastupdated", "dismissButton", "bar", "wrapper"]

  connect() {
    this.updateHandler = this.update.bind(this)
    window.addEventListener("task-status:update", this.updateHandler)

    // Auto-scroll once on connect
    this.wrapperTarget?.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  disconnect() {
    window.removeEventListener("task-status:update", this.updateHandler)
  }

  update(event) {
    const { detail } = event
    // Remove the container if the task has been dismissed or deleted
    if (detail.status === "dismissed" || detail.deleted) {
      if (this.wrapperTarget) {
        this.wrapperTarget.remove()
      } else {
        this.element.remove()
      }
      return
    }
    if (detail.task_id !== this.taskIdValue) return

    if (this.hasStatusTarget) this.statusTarget.textContent = detail.status
    if (this.hasMessageTarget) this.messageTarget.textContent = detail.message
    if (this.hasLastupdatedTarget) this.lastupdatedTarget.textContent = new Date(detail.updated_at).toLocaleString()
    if (this.hasDismissButtonTarget) {
      if (detail.status === "completed" || detail.status === "failed") {
        this.dismissButtonTarget.style.display = "inline-block"
        this.dismissButtonTarget.onclick = () => this.dismiss()
      }
    }

    this.element.classList.remove("text-yellow-600", "text-green-600", "text-red-600")

    switch (detail.status) {
      case "completed":
        this.element.classList.add("text-green-600")
        this.updateProgressBar(100, "bg-green-600")
        this.toggleQuestionnaireResponseButtons()
        this.toggleQuestionnaireResponseRowBackground()
        break
      case "failed":
        this.element.classList.add("text-red-600")
        this.updateProgressBar(100, "bg-red-600")
        break
      case "running":
        this.element.classList.add("text-yellow-600")
        this.updateProgressBar(50, "bg-blue-600 animate-pulse")
        break
      case "pending":
        this.element.classList.add("text-yellow-600")
        this.updateProgressBar(10, "bg-blue-400 animate-pulse")
        break
    }
  }

  updateProgressBar(percent, classes) {
    if (!this.hasBarTarget) return

    this.barTarget.style.width = `${percent}%`
    this.barTarget.className =
      `h-2.5 rounded-full transition-all duration-500 ${classes}`
  }

  dismiss() {
    fetch(`/task_statuses/${this.taskIdValue}/dismiss`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      }
    })
      .then(() => {
        if (this.wrapperTarget) {
          this.wrapperTarget.remove()
        } else {
          this.element.remove()
        }
      })
  }

  // This function toggles the visibility of the "Convert to PFE assessments" and "View derived assessments" buttons
  // When the task status updates to 'completed', it shows the "View derived assessments" button and hides
  // the "Convert to PFE assessments" button
  toggleQuestionnaireResponseButtons() {
    const convertButton = document.getElementById(`convert-qr-${this.taskIdValue}`)
    const viewDerivedButton = document.getElementById(`view-derived-assessments-${this.taskIdValue}`)
    if (convertButton && viewDerivedButton) {
      convertButton.classList.remove('flex')
      convertButton.classList.add('hidden')

      viewDerivedButton.classList.remove('hidden')
      viewDerivedButton.classList.add('flex')
    }

  }

  // Change QR row background color when observations are present (task completed) and make icon visible
  toggleQuestionnaireResponseRowBackground() {
    const row = document.getElementById(`table-column-header-${this.taskIdValue}`)
    const icon = document.getElementById(`icon-${this.taskIdValue}`)
    if (row) {
      row.classList.remove('bg-white')
      row.classList.add('bg-green-50')
    }
    if (icon) {
      icon.classList.remove('hidden')
      icon.classList.add('inline-flex')
    }
  }
}
