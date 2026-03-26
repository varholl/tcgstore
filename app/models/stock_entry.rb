class StockEntry < ApplicationRecord
  belongs_to :card

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :added_at, presence: true
end
