// app/javascript/controllers/visibility_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "authenticatedInput", "credentialFields", "requiredFields" ]
  static values = { showIf: String }
  connect() {
    this.toggle()
  }

  toggle() {
    if (this.authenticatedInputTarget.value != this.showIfValue) {
      this.credentialFieldsTarget.hidden = true;
      this.requiredFieldsTargets.forEach(el => {
        el.required = false;
      });
    } else if (this.authenticatedInputTarget.value == this.showIfValue) {
      this.credentialFieldsTarget.hidden = false;
      this.requiredFieldsTargets.forEach(el => {
        el.required = true;
      });
    }
  }
}
