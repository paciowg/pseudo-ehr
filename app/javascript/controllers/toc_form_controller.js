import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toc-form"
export default class extends Controller {
  static targets = ["title", "form", "sectionCheckbox", "entryCheckbox", "sectionError"]

  connect() {
    console.log("TOC form controller connected")
  }

  autoFill(event) {
    event.preventDefault()
    console.log("Auto-fill button clicked")

    // Fill in basic fields
    if (this.hasTitleTarget) {
      this.titleTarget.value = this.titleTarget.dataset.patientName ?
        `Transfer Summary for ${this.titleTarget.dataset.patientName}` :
        'Transfer Summary'
    }

    // Check all section checkboxes
    this.sectionCheckboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })

    // Map section IDs to their corresponding entry checkbox classes
    const sectionEntryMap = {
      'section_allergies': '.allergy-entry',
      'section_medications': '.medication-entry, .medication-list-entry',
      'section_problems': '.condition-entry',
      'section_procedures': '.procedure-entry',
      'section_results': '.observation-entry',
      'section_vital_signs': '.observation-vital-entry',
      'section_immunizations': '.immunization-entry',
      'section_advance_directives': '.docref-entry'
    }

    // Check each section
    Object.keys(sectionEntryMap).forEach(sectionId => {
      const checkbox = document.getElementById(sectionId)
      if (checkbox && checkbox.checked) {

        // Get entries for this section
        const entrySelector = sectionEntryMap[sectionId]
        const entryCheckboxes = Array.from(document.querySelectorAll(entrySelector))

        // Select up to 5 entries
        const numToSelect = Math.min(5, entryCheckboxes.length)
        for (let i = 0; i < numToSelect; i++) {
          entryCheckboxes[i].checked = true
        }
      }
    })

    // Select options in remaining selects (for author and custodian)
    document.querySelectorAll('select').forEach(select => {
      if (select.options.length > 1) {
        select.options[1].selected = true
      }
    })

    this.validateForm()
  }

  validateForm() {
    // Check if at least 4 sections are selected
    const checkedSections = this.sectionCheckboxTargets.filter(checkbox => checkbox.checked).length

    if (checkedSections < 4) {
      this.sectionErrorTarget.classList.remove("hidden")
      return false
    } else {
      this.sectionErrorTarget.classList.add("hidden")
      return true
    }
  }

  validateOnSubmit(event) {
    if (!this.validateForm()) {
      event.preventDefault()
    }
  }

  clearForm() {
    // Clear title field
    if (this.hasTitleTarget) {
      this.titleTarget.value = ''
    }

    // Reset all selects to first option
    document.querySelectorAll('select').forEach(select => {
      select.selectedIndex = 0
    })

    // Uncheck all section checkboxes
    this.sectionCheckboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })

    // Uncheck all entry checkboxes
    this.entryCheckboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })

    // Hide any error messages
    if (this.hasSectionErrorTarget) {
      this.sectionErrorTarget.classList.add("hidden")
    }
  }
}
