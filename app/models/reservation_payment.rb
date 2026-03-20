class ReservationPayment < ApplicationRecord
  belongs_to :reservation

  validates :amount, presence: true, numericality: { greater_than: 0 }
end
