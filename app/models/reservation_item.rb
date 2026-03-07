class ReservationItem < ApplicationRecord
  belongs_to :reservation
  belongs_to :card

  validates :quantity, numericality: { greater_than: 0 }
end
