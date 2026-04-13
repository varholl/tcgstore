import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "searchResults"]

  async search(event) {
    event.preventDefault()
    const query = this.searchInputTarget.value.trim()
    if (!query) return

    const url = this.element.dataset.searchUrl + "?query=" + encodeURIComponent(query)
    const response = await fetch(url, {
      headers: { "X-Requested-With": "XMLHttpRequest" }
    })
    const html = await response.text()
    this.searchResultsTarget.innerHTML = html
  }

  sell(event) {
    event.preventDefault()
    const cardId = event.currentTarget.dataset.cardId
    const walkInUrl = this.element.dataset.walkInUrl
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    const form = document.createElement("form")
    form.method = "POST"
    form.action = walkInUrl

    const cardInput = document.createElement("input")
    cardInput.type = "hidden"
    cardInput.name = "card_id"
    cardInput.value = cardId

    const qtyInput = document.createElement("input")
    qtyInput.type = "hidden"
    qtyInput.name = "quantity"
    qtyInput.value = "1"

    const tokenInput = document.createElement("input")
    tokenInput.type = "hidden"
    tokenInput.name = "authenticity_token"
    tokenInput.value = csrfToken

    form.appendChild(cardInput)
    form.appendChild(qtyInput)
    form.appendChild(tokenInput)
    document.body.appendChild(form)
    form.submit()
  }
}
