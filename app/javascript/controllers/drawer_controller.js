import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drawer"
export default class extends Controller {
  static targets = ["content"]
  static values = {
    visible: Boolean
  }

  visibleValueChanged() {
    this.updateVisibility()
  }

  toggle() {
    this.visibleValue = !this.visibleValue
    this.updateVisibility()
    this.persistDrawerState()
  }

  updateVisibility() {
    this.contentTarget.classList.toggle("hidden", !this.visibleValue)
    if (this.visibleValue) {
      this.dispatch("opened")
    }
  }

  persistDrawerState() {
    const state = { visible: this.visibleValue };
    const csrfToken = document.querySelector("meta[name='csrf-token']").content;

    fetch('/persistent_states/drawer', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify(state)
    });
  }
}
