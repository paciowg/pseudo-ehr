import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.style.display = 'none';
    this.showSpinner = this.showSpinner.bind(this);
    this.hideSpinner = this.hideSpinner.bind(this);
    document.addEventListener('turbo:submit-start', this.showSpinner);
    document.addEventListener('turbo:submit-end', this.hideSpinner);
  }

  disconnect() {
    document.removeEventListener('turbo:submit-start', this.showSpinner);
    document.removeEventListener('turbo:submit-end', this.hideSpinner);
  }

  showSpinner() {
    this.element.style.display = 'flex';
  }

  hideSpinner() {
    this.element.style.display = 'none';
  }
}
