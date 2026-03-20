import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:frame-render", this.scrollToTop)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-render", this.scrollToTop)
  }

  scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }
}
