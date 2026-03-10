import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const toast = new bootstrap.Toast(this.element, { delay: 4000 })
    toast.show()
  }
}
