import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.style.display = 'none';  // Initially hide the spinner
    this.showSpinner = this.showSpinner.bind(this);
    this.hideSpinner = this.hideSpinner.bind(this);
    document.addEventListener('turbo:submit-start', this.showSpinner);
    document.addEventListener('turbo:load', this.hideSpinner);
  }

  disconnect() {
    document.removeEventListener('turbo:submit-start', this.showSpinner);
    document.removeEventListener('turbo:load', this.hideSpinner);
  }

  showSpinner() {
    this.element.style.display = 'flex';  // Show spinner
  }

  hideSpinner() {
    this.element.style.display = 'none';  // Hide spinner
  }
}
