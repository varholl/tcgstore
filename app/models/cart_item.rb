class CartItem < ApplicationRecord
  belongs_to :user
  belongs_to :card

  validates :card_id, uniqueness: { scope: :user_id, message: "is already in your cart" }
  validates :quantity, numericality: { greater_than: 0 }
end
