import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "formatSelect", "sinceInput", "untilInput"]

  open() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
    }
  }

  submit(event) {
    // Form submits naturally; close modal after
    setTimeout(() => this.close(), 100)
  }
}
