import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput", "searchResults", "searchSpinner",
    "stockForm", "selectedCardInfo",
    "nameField", "scryfallIdField", "setCodeField", "setNameField", "collectorNumberField", "priceField"
  ]

  async search(event) {
    event.preventDefault()
    const query = this.searchInputTarget.value.trim()
    if (!query) return

    this.searchSpinnerTarget.classList.remove("d-none")
    this.searchResultsTarget.innerHTML = ""

    const url = this.element.dataset.searchUrl + "?query=" + encodeURIComponent(query)
    try {
      const response = await fetch(url, {
        headers: { "X-Requested-With": "XMLHttpRequest" }
      })
      const html = await response.text()
      this.searchResultsTarget.innerHTML = html
    } catch (error) {
      this.searchResultsTarget.innerHTML = '<div class="alert alert-danger">Search failed. Please try again.</div>'
    } finally {
      this.searchSpinnerTarget.classList.add("d-none")
    }
  }

  select(event) {
    event.preventDefault()
    const btn = event.currentTarget

    this.nameFieldTarget.value = btn.dataset.name
    this.scryfallIdFieldTarget.value = btn.dataset.scryfallId
    this.setCodeFieldTarget.value = btn.dataset.setCode
    this.setNameFieldTarget.value = btn.dataset.setName
    this.collectorNumberFieldTarget.value = btn.dataset.collectorNumber
    this.priceFieldTarget.value = btn.dataset.price || ""

    this.selectedCardInfoTarget.innerHTML = `
      <strong>${this.escapeHtml(btn.dataset.name)}</strong>
      <span class="text-muted">— ${this.escapeHtml(btn.dataset.setName)} #${this.escapeHtml(btn.dataset.collectorNumber)}</span>
    `

    this.stockFormTarget.classList.remove("d-none")
    this.stockFormTarget.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
