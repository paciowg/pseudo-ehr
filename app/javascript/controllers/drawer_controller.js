import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drawer"
export default class extends Controller {
  static targets = ["content"]
  static values = {
    sessionKey: String,
    visible: Boolean
  }

  connect() {
    this.updateVisibility()
  }

  toggle() {
    this.visibleValue = !this.visibleValue
    this.updateVisibility()
    this.updateSession()
  }

  updateVisibility() {
    this.contentTarget.classList.toggle("hidden", !this.visibleValue)
  }

  updateSession() {
    if (!this.hasSessionKeyValue) return

    const body = { key: this.sessionKeyValue, value: this.visibleValue };
    const csrfToken = document.querySelector("meta[name='csrf-token']").content;

    fetch('/persistent_state', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify(body)
    });
  }
}
