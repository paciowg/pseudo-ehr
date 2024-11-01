import { Controller } from "@hotwired/stimulus"
import debounce from "debounce";

// Connects to data-controller="form"
export default class extends Controller {
  initialize() {
    this.submit = debounce(this.submit.bind(this), 300);
  }

  submit() {
    if (window.Turbo) {
      this.element.requestSubmit();
    } else {
      this.element.submit();
    }
  }
}
