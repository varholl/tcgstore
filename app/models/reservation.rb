class Reservation < ApplicationRecord
  belongs_to :user, optional: true
  has_many :reservation_items, dependent: :destroy

  enum :status, { pending: "pending", fulfilled: "fulfilled", expired: "expired", cancelled: "cancelled" }

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
