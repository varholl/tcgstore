class Reservation < ApplicationRecord
  belongs_to :user
  has_many :reservation_items, dependent: :destroy

  enum status: { pending: "pending", fulfilled: "fulfilled", expired: "expired", cancelled: "cancelled" }

  validates :message, length: { maximum: 1000 }
end
