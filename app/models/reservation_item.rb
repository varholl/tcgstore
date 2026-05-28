class ReservationItem < ApplicationRecord
  belongs_to :reservation
  belongs_to :card

  # Per-item problem flags raised while preparing an order.
  enum :issue, {
    wrong_condition: "wrong_condition",
    wrong_set: "wrong_set",
    wrong_language: "wrong_language",
    out_of_stock: "out_of_stock"
  }, validate: { allow_nil: true }

  validates :quantity, numericality: { greater_than: 0 }
  validates :issue_note, length: { maximum: 500 }
end
