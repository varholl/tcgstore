class Card < ApplicationRecord
  belongs_to :seller
  has_many :reservation_items
  has_many :stock_entries

  validates :name, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  before_save :touch_last_stocked_at, if: -> { quantity_changed? && quantity > quantity_was.to_i }

  scope :search_by_name, ->(query) {
    if query.present?
      terms = query.strip.split(/\s+/)
      terms.inject(all) { |scope, term| scope.where("cards.name LIKE ?", "%#{term}%") }
    end
  }
  scope :filter_by_edition, ->(edition) { where(edition: edition) if edition.present? }

  def card_identity
    [edition.to_s.downcase, collector_number.to_s.strip, condition, language, foil]
  end

  def sibling_cards
    Card.where(edition: edition, collector_number: collector_number,
               condition: condition, language: language, foil: foil)
  end

  def active_sibling_cards
    sibling_cards.joins(:seller).merge(Seller.active)
  end

  def grouped_available_quantity
    active_siblings = active_sibling_cards
    total_qty = active_siblings.sum(:quantity)
    total_reserved = ReservationItem.joins(:reservation)
      .where(card_id: active_siblings.select(:id))
      .where(reservations: { status: %w[pending prepared paid] })
      .sum(:quantity)
    total_qty - total_reserved
  end

  def foil_display
    case foil_type
    when "surge" then "Surge Foil"
    when "etched" then "Etched Foil"
    else "Foil"
    end
  end

  def available_quantity
    return 0 if seller.suspended?

    reserved = reservation_items.joins(:reservation)
      .where(reservations: { status: %w[pending prepared paid] })
      .sum(:quantity)
    quantity - reserved
  end

  private

  def touch_last_stocked_at
    self.last_stocked_at = Time.current
  end
end
