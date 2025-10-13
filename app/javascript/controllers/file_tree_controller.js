import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  connect() {
    this.activeLinkClass = "font-bold"
  }

  select(event) {
    this.linkTargets.forEach(link => {
      link.classList.remove(this.activeLinkClass)
    })
    event.currentTarget.classList.add(this.activeLinkClass)
  }
}
