import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails";

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

  navigate(event) {
    event.preventDefault();
    const url = event.currentTarget.dataset.url;

    // Navigate to the URL
    if (url) {
      // window.location.href = url;
      Turbo.visit(url);
    }
  }
}
