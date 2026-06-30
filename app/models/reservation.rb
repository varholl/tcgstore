class Reservation < ApplicationRecord
  DELIVERY_LOCATIONS = %w[batikueva magic_palace correo moto otro].freeze
  SHIPPING_METHODS = %w[store_pickup bike_delivery andreani correo_argentino].freeze
  PICKUP_LOCATIONS = %w[batikueva magic_palace].freeze

  belongs_to :user, optional: true
  has_many :reservation_items, dependent: :destroy
  has_many :reservation_notes, dependent: :destroy
  has_many :reservation_payments, dependent: :destroy

  enum :status, { pending: "pending", in_preparation: "in_preparation", prepared: "prepared", paid: "paid", shipped: "shipped", fulfilled: "fulfilled", expired: "expired", cancelled: "cancelled" }

  scope :with_price_changes, -> {
    where(status: [:pending, :in_preparation, :prepared])
      .where(
        id: ReservationItem.joins(:card)
          .where.not(unit_price: nil)
          .where("reservation_items.unit_price != cards.price")
          .select(:reservation_id)
      )
  }

  def total_price
    final_price.presence || reservation_items.sum { |i| (i.unit_price || 0) * i.quantity }
  end

  def prepared_items_count
    reservation_items.count(&:prepared?)
  end

  def flagged_items_count
    reservation_items.count { |i| i.issue.present? }
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

  # A public note authored by someone other than the owner (i.e. an admin/seller
  # reply) that the owner hasn't seen yet. Works on a preloaded association
  # without firing per-record queries when reservation_notes is included.
  def unread_notes_for_owner?
    return false if guest?

    latest = reservation_notes
      .select { |n| n.public? && n.user_id != user_id }
      .map(&:created_at).max
    return false if latest.nil?

    owner_notes_read_at.nil? || latest > owner_notes_read_at
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
