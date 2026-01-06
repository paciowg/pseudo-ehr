// app/javascript/controllers/showhide_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "authenticatedInput", "credentialFields", "requiredFields",
    "adiStatus", "currentAdis", "supersededAdis",
    "obsType", "singleObs", "collectionObs", "conditionType",
    "encounterDiagnosis", "problemListItem", "other",
    "tocConditionButton", "tocConditionContent", "tocServiceRequestButton",
     "tocServiceRequestContent", "tocAllergyButton", "tocAllergyContent",
     "tocCarePlanContent", "tocCarePlanButton", "tocObservationButton", "tocObservationContent",
     "trendObs"
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
    const value = this.obsTypeTarget.value

    if (value === "Single Observations") {
      this.singleObsTargets.forEach(el => el.classList.remove('hidden'))
      if (this.hasCollectionObsTarget) {
        this.collectionObsTargets.forEach(el => el.classList.add('hidden'))
      }
      if (this.hasTrendObsTarget) {
        this.trendObsTargets.forEach(el => el.classList.add('hidden'))
      }
    } else if (value === "Observation Collection") {
      this.singleObsTargets.forEach(el => el.classList.add('hidden'))
      if (this.hasCollectionObsTarget) {
        this.collectionObsTargets.forEach(el => el.classList.remove('hidden'))
      }
      if (this.hasTrendObsTarget) {
        this.trendObsTargets.forEach(el => el.classList.add('hidden'))
      }
    } else if (value === "Observation Trends") {
      this.singleObsTargets.forEach(el => el.classList.add('hidden'))
      if (this.hasCollectionObsTarget) {
        this.collectionObsTargets.forEach(el => el.classList.add('hidden'))
      }
      if (this.hasTrendObsTarget) {
        this.trendObsTargets.forEach(el => el.classList.remove('hidden'))
      }
    }
  }

  toggleConditions() {
    if (this.conditionTypeTarget.value === "Condition Problem/Health Concern") {
      this.problemListItemTargets.forEach(el => {
        el.hidden = false;
      })
      this.encounterDiagnosisTargets.forEach(el => {
        el.hidden = true;
      })
      this.otherTargets.forEach(el => {
        el.hidden = true;
      })
    } else if (this.conditionTypeTarget.value === "Encounter Diagnosis") {
      this.problemListItemTargets.forEach(el => {
        el.hidden = true;
      })
      this.otherTargets.forEach(el => {
        el.hidden = true;
      })
      this.encounterDiagnosisTargets.forEach(el => {
        el.hidden = false;
      })
    } else if (this.conditionTypeTarget.value === "Other") {
      this.problemListItemTargets.forEach(el => {
        el.hidden = true;
      })
      this.otherTargets.forEach(el => {
        el.hidden = false;
      })
      this.encounterDiagnosisTargets.forEach(el => {
        el.hidden = true;
      })
    } else {
      this.problemListItemTargets.forEach(el => {
        el.hidden = false;
      })
      this.otherTargets.forEach(el => {
        el.hidden = false;
      })
      this.encounterDiagnosisTargets.forEach(el => {
        el.hidden = false;
      })
    }
  }

  // toggleTocConditions(event) {
  //   event.stopPropagation()

  //   if (this.tocConditionButtonTarget.textContent.trim() === "Show conditions") {
  //     this.tocConditionButtonTarget.textContent = "Hide conditions";
  //     this.tocConditionTargets.forEach(el => {
  //       el.hidden = false;
  //     })
  //   } else if (this.tocConditionButtonTarget.textContent.trim() === "Hide conditions") {
  //     this.tocConditionButtonTarget.textContent = "Show conditions";
  //     this.tocConditionTargets.forEach(el => {
  //       el.hidden = true;
  //     })
  //   }
  // }
  toggleSection(event) {
    event.stopPropagation();

    const button = event.currentTarget;
    const content = this.tocConditionContentTargets.concat(this.tocServiceRequestContentTargets)
    .concat(this.tocAllergyContentTargets).concat(this.tocCarePlanContentTargets)
    .concat(this.tocObservationContentTargets);

    if (button.textContent.trim().includes("Show")) {
      button.textContent = button.textContent.replace("Show", "Hide");
      content.forEach(el => {
        el.hidden = false;
      });
    } else {
      button.textContent = button.textContent.replace("Hide", "Show");
      content.forEach(el => {
        el.hidden = true;
      });
    }
  }

}
