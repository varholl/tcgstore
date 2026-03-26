class Seller < ApplicationRecord
  belongs_to :user, optional: true
  has_many :cards

  validates :name, presence: true

  scope :default, -> { find_by(default: true) }
end
