import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modeSection", "newSetSection", "newSetCheckbox"]

  toggleFormat(event) {
    const isManabox = event.target.value === "manabox"
    this.modeSectionTarget.style.display = isManabox ? "none" : ""
  }

  toggleNewSet() {
    this.newSetSectionTarget.style.display = this.newSetCheckboxTarget.checked ? "" : "none"
  }
}
