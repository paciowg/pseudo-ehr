import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "content"]
  static values = {
    open: { type: Boolean, default: false }
  }

  connect() {
    this.escapeHandler = this.escapeHandler.bind(this)
    document.addEventListener("keydown", this.escapeHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
  }

  escapeHandler(event) {
    if (event.key === "Escape" && this.openValue) {
      this.close()
    }
  }

  open(event) {
    if (event) {
      const modalId = event.currentTarget.dataset.modalId
      if (modalId) {
        const modalElement = document.getElementById(modalId)
        if (modalElement && modalElement.dataset.controller === "modal") {
          const modalController = this.application.getControllerForElementAndIdentifier(modalElement, "modal")
          if (modalController) {
            modalController.openDirectly()
            return
          }
        }
      }
    }

    this.openDirectly()
  }

  openDirectly() {
    this.containerTarget.classList.remove("hidden")
    this.containerTarget.classList.add("flex")
    document.body.style.overflow = "hidden"

    setTimeout(() => {
      this.contentTarget.classList.remove("scale-95", "opacity-0")
      this.contentTarget.classList.add("scale-100", "opacity-100")
    }, 10)

    this.openValue = true
  }

  close() {
    this.contentTarget.classList.remove("scale-100", "opacity-100")
    this.contentTarget.classList.add("scale-95", "opacity-0")

    setTimeout(() => {
      this.containerTarget.classList.add("hidden")
      this.containerTarget.classList.remove("flex")
      document.body.style.overflow = ""
    }, 300)

    this.openValue = false
  }

  clickOutside(event) {
    if (event.target === this.containerTarget) {
      this.close()
    }
  }

  resetForm() {
    // Find the form within the modal
    const form = this.element.querySelector('form')
    if (form) {
      form.reset()
    }
  }
}
