class Card < ApplicationRecord
  has_many :reservation_items

  validates :name, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  scope :search_by_name, ->(query) {
    if query.present?
      terms = query.strip.split(/\s+/)
      terms.inject(all) { |scope, term| scope.where("name LIKE ?", "%#{term}%") }
    end
  }
  scope :filter_by_edition, ->(edition) { where(edition: edition) if edition.present? }

  def foil_display
    case foil_type
    when "surge" then "Surge Foil"
    when "etched" then "Etched Foil"
    else "Foil"
    end
  end

  def available_quantity
    reserved = reservation_items.joins(:reservation)
      .where(reservations: { status: %w[pending prepared paid fulfilled] })
      .sum(:quantity)
    quantity - reserved
  end
end
