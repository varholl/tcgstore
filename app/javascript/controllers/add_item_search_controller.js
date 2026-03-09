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
}
