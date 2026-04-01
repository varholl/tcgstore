class Seller < ApplicationRecord
  belongs_to :user, optional: true
  has_many :cards

  validates :name, presence: true

  scope :default, -> { find_by(default: true) }
  scope :active, -> { where(suspended: false) }
  scope :suspended, -> { where(suspended: true) }
end
