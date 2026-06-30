import { Controller } from "@hotwired/stimulus"

// Remembers dismissal per browser via localStorage. The key embeds the
// announcement's updated_at, so editing an announcement re-shows it.
export default class extends Controller {
  static values = { key: String }

  connect() {
    if (localStorage.getItem(this.keyValue)) {
      this.element.remove()
    }
  }

  dismiss() {
    localStorage.setItem(this.keyValue, "1")
    this.element.remove()
  }
}
