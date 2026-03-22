class ReservationNote < ApplicationRecord
  belongs_to :reservation
  belongs_to :user, optional: true

  validates :body, presence: true

  scope :internal, -> { where(public: false) }
  scope :public_notes, -> { where(public: true) }
end
