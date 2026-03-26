import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["locationSelect", "otherField"]

  toggleOther() {
    const isOtro = this.locationSelectTarget.value === "otro"
    this.otherFieldTarget.style.display = isOtro ? "" : "none"
  }
}
