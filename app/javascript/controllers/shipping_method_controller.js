import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["storePickupOptions", "bikeDeliveryOptions", "andreaniOptions", "correoOptions", "submitButton"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.element.querySelector('input[name="shipping_method"]:checked')?.value

    const sections = {
      store_pickup: this.hasStorePickupOptionsTarget ? this.storePickupOptionsTarget : null,
      bike_delivery: this.hasBikeDeliveryOptionsTarget ? this.bikeDeliveryOptionsTarget : null,
      andreani: this.hasAndreaniOptionsTarget ? this.andreaniOptionsTarget : null,
      correo_argentino: this.hasCorreoOptionsTarget ? this.correoOptionsTarget : null
    }

    Object.entries(sections).forEach(([method, target]) => {
      if (target) {
        target.style.display = selected === method ? "" : "none"
      }
    })

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !selected
    }
  }
}
