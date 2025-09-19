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
    this.persistDrawerState()
  }

  updateVisibility() {
    this.contentTarget.classList.toggle("hidden", !this.visibleValue)
  }

  persistDrawerState() {
    if (!this.hasSessionKeyValue) return

    const body = { session_key: this.sessionKeyValue, visible: this.visibleValue };
    const csrfToken = document.querySelector("meta[name='csrf-token']").content;

    fetch('/persistent_states/drawer', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify(body)
    });
  }
}
