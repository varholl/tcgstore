import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput", "searchResults", "searchSpinner",
    "stockForm", "selectedCardInfo",
    "nameField", "scryfallIdField", "setCodeField", "setNameField", "collectorNumberField", "priceField", "foilTypeField",
    "colorsField", "manaCostField", "cmcField", "cardTypeField", "cardSubtypeField", "rarityField",
    "conditionSelect", "foilCheckbox"
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
    this.foilTypeFieldTarget.value = btn.dataset.foilType
    this.colorsFieldTarget.value = btn.dataset.colors || ""
    this.manaCostFieldTarget.value = btn.dataset.manaCost || ""
    this.cmcFieldTarget.value = btn.dataset.cmc || ""
    this.cardTypeFieldTarget.value = btn.dataset.cardType || ""
    this.cardSubtypeFieldTarget.value = btn.dataset.cardSubtype || ""
    this.rarityFieldTarget.value = btn.dataset.rarity || ""

    // Store condition prices for dynamic updates
    this._conditionPrices = JSON.parse(btn.dataset.ckConditionPrices || "{}")
    this._conditionPricesFoil = JSON.parse(btn.dataset.ckConditionPricesFoil || "{}")
    this._fallbackPrice = btn.dataset.fallbackPrice || ""

    this._updatePrice()

    this.selectedCardInfoTarget.innerHTML = `
      <strong>${this.escapeHtml(btn.dataset.name)}</strong>
      <span class="text-muted">— ${this.escapeHtml(btn.dataset.setName)} #${this.escapeHtml(btn.dataset.collectorNumber)}</span>
    `

    this.stockFormTarget.classList.remove("d-none")
    this.stockFormTarget.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  updatePrice() {
    this._updatePrice()
  }

  _updatePrice() {
    if (!this._conditionPrices) return

    const condition = this.conditionSelectTarget.value
    const isFoil = this.foilCheckboxTarget.checked
    const prices = isFoil ? this._conditionPricesFoil : this._conditionPrices
    const price = prices[condition]

    this.priceFieldTarget.value = price || this._fallbackPrice || ""
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
