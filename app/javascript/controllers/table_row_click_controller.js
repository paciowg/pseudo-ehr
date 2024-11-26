import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails";

// Connects to data-controller="table-row-click"
export default class extends Controller {
  connect() {
    this.element.style.cursor = 'pointer';
  }

  goToLink(event) {
    const url = this.data.get("url");
    if (url) {
      // window.location = url;
      Turbo.visit(url);
    }
  }
}
