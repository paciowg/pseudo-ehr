// app/javascript/controllers/visibility_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "authenticatedInput", "credentialFields", "requiredFields",
    "adiStatus", "currentAdis", "supersededAdis",
    "obsType", "singleObs", "collectionObs"
  ]
  static values = { showIf: String }
  connect() {
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

  toggleAdiStatus() {
    if (this.adiStatusTarget.value === "All") {
      this.currentAdisTargets.forEach(el => {
        el.hidden = false;
      })
      this.supersededAdisTargets.forEach(el => {
        el.hidden = false;
      })
    } else if ((this.adiStatusTarget.value === "Current")) {
      this.currentAdisTargets.forEach(el => {
        el.hidden = false;
      })
      this.supersededAdisTargets.forEach(el => {
        el.hidden = true;
      })
    } else if ((this.adiStatusTarget.value === "Superseded")){
      this.currentAdisTargets.forEach(el => {
        el.hidden = true;
      })
      this.supersededAdisTargets.forEach(el => {
        el.hidden = false;
      })
    }
  }

  toggleObservations() {
    if (this.obsTypeTarget.value === "Single Observations") {
      this.singleObsTargets.forEach(el => {
        el.hidden = false;
      })
      this.collectionObsTargets.forEach(el => {
        el.hidden = true;
      })
    } else if (this.obsTypeTarget.value === "Observation Collection") {
      this.singleObsTargets.forEach(el => {
        el.hidden = true;
      })
      this.collectionObsTargets.forEach(el => {
        el.hidden = false;
      })
    }
  }
}
