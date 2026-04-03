import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modeSection", "preorderSection", "preorderCheckbox"]

  toggleFormat(event) {
    const isManabox = event.target.value === "manabox"
    this.modeSectionTarget.style.display = isManabox ? "none" : ""
  }

  togglePreorder() {
    this.preorderSectionTarget.style.display = this.preorderCheckboxTarget.checked ? "" : "none"
  }
}
