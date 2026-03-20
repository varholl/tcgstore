class Reservation < ApplicationRecord
  belongs_to :user, optional: true
  has_many :reservation_items, dependent: :destroy
  has_many :reservation_notes, dependent: :destroy
  has_many :reservation_payments, dependent: :destroy

  enum :status, { pending: "pending", prepared: "prepared", paid: "paid", fulfilled: "fulfilled", expired: "expired", cancelled: "cancelled" }

  def total_price
    final_price.presence || reservation_items.sum { |i| (i.unit_price || 0) * i.quantity }
  end

  def total_paid
    reservation_payments.sum(:amount)
  end

  def remaining_balance
    total_price - total_paid
  end

  validates :message, length: { maximum: 1000 }
  validates :guest_name, :guest_contact, presence: true, unless: :user_id?

  def guest?
    user_id.blank?
  end

  def display_name
    guest? ? guest_name : user.name
  end

  def display_email
    guest? ? guest_contact : user.email
  end

  def display_phone
    guest? ? guest_contact : user.phone_number
  end
end
