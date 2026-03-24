import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modeSection"]

  toggleFormat(event) {
    const isManabox = event.target.value === "manabox"
    this.modeSectionTarget.style.display = isManabox ? "none" : ""
  }
}
