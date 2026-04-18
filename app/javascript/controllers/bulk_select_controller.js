import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "selectAll", "bar", "count", "idsContainer", "submit"]

  connect() {
    this.refresh()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach((cb) => { cb.checked = checked })
    this.refresh()
  }

  refresh() {
    const selected = this.checkboxTargets.filter((cb) => cb.checked)
    const count = selected.length

    if (this.hasCountTarget) this.countTarget.textContent = count
    if (this.hasBarTarget) this.barTarget.classList.toggle("d-none", count === 0)
    if (this.hasSubmitTarget) this.submitTarget.disabled = count === 0
    if (this.hasSelectAllTarget) {
      const total = this.checkboxTargets.length
      this.selectAllTarget.checked = total > 0 && count === total
      this.selectAllTarget.indeterminate = count > 0 && count < total
    }

    if (this.hasIdsContainerTarget) {
      this.idsContainerTarget.innerHTML = ""
      selected.forEach((cb) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "card_ids[]"
        input.value = cb.value
        this.idsContainerTarget.appendChild(input)
      })
    }
  }
}
