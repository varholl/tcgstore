import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customerType", "userFields", "guestFields", "searchInput", "searchResults", "selectedCards", "selectedCardsBody", "itemsContainer"]

  connect() {
    this.selectedItems = []
  }

  toggleCustomerType(event) {
    const type = event.target.value
    if (type === "existing") {
      this.userFieldsTarget.classList.remove("d-none")
      this.guestFieldsTarget.classList.add("d-none")
    } else {
      this.userFieldsTarget.classList.add("d-none")
      this.guestFieldsTarget.classList.remove("d-none")
    }
  }

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

  add(event) {
    event.preventDefault()
    const button = event.currentTarget
    const cardId = button.dataset.cardId
    const cardName = button.dataset.cardName
    const cardEdition = button.dataset.cardEdition
    const cardCondition = button.dataset.cardCondition
    const available = parseInt(button.dataset.cardAvailable)

    const existing = this.selectedItems.find(item => item.cardId === cardId)
    if (existing) {
      if (existing.quantity < available) {
        existing.quantity++
      }
    } else {
      this.selectedItems.push({
        cardId,
        cardName,
        cardEdition,
        cardCondition,
        available,
        quantity: 1
      })
    }

    this.renderSelected()
  }

  remove(event) {
    event.preventDefault()
    const cardId = event.currentTarget.dataset.cardId
    this.selectedItems = this.selectedItems.filter(item => item.cardId !== cardId)
    this.renderSelected()
  }

  updateQuantity(event) {
    const cardId = event.target.dataset.cardId
    const newQty = parseInt(event.target.value)
    const item = this.selectedItems.find(i => i.cardId === cardId)
    if (item) {
      item.quantity = Math.max(1, Math.min(newQty, item.available))
      event.target.value = item.quantity
    }
    this.renderHiddenInputs()
  }

  renderSelected() {
    if (this.selectedItems.length === 0) {
      this.selectedCardsTarget.classList.add("d-none")
    } else {
      this.selectedCardsTarget.classList.remove("d-none")
    }

    this.selectedCardsBodyTarget.innerHTML = this.selectedItems.map(item => `
      <tr>
        <td>${this.escapeHtml(item.cardName)}</td>
        <td>${this.escapeHtml(item.cardEdition)}</td>
        <td>${this.escapeHtml(item.cardCondition)}</td>
        <td>
          <input type="number" min="1" max="${item.available}" value="${item.quantity}"
                 class="form-control form-control-sm" style="width: 80px"
                 data-card-id="${item.cardId}"
                 data-action="change->admin-card-selector#updateQuantity">
        </td>
        <td>
          <button type="button" class="btn btn-sm btn-outline-danger"
                  data-card-id="${item.cardId}"
                  data-action="click->admin-card-selector#remove">&times;</button>
        </td>
      </tr>
    `).join("")

    this.renderHiddenInputs()
  }

  renderHiddenInputs() {
    this.itemsContainerTarget.innerHTML = this.selectedItems.map((item, index) => `
      <input type="hidden" name="reservation[items][${index}][card_id]" value="${item.cardId}">
      <input type="hidden" name="reservation[items][${index}][quantity]" value="${item.quantity}">
    `).join("")
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
