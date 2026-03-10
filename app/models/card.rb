class Card < ApplicationRecord
  has_many :reservation_items

  validates :name, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  scope :search_by_name, ->(query) { where("name LIKE ?", "%#{query}%") if query.present? }
  scope :filter_by_edition, ->(edition) { where(edition: edition) if edition.present? }

  def available_quantity
    reserved = reservation_items.joins(:reservation)
      .where(reservations: { status: %w[pending paid] })
      .sum(:quantity)
    quantity - reserved
  end
end
