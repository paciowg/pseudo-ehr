import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="menu"
export default class extends Controller {
  static targets = ["item"];

  connect() {
    this.setActiveBasedOnUrl();
  }

  setActiveBasedOnUrl() {
    const currentPath = window.location.pathname;
    this.itemTargets.forEach((item) => {
      if (item.getAttribute('href') === currentPath) {
        item.classList.add("bg-blue-500", "text-white");
      } else {
        item.classList.remove("bg-blue-500", "text-white");
      }
    })
  }

  setActive(event) {
    // Remove active class from all items
    this.itemTargets.forEach((item) => {
      item.classList.remove("bg-blue-500", "text-white");
    });

    // Add active class to the clicked item
    event.currentTarget.classList.add("bg-blue-500", "text-white");
  }
}
