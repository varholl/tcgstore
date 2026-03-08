class ReservationNote < ApplicationRecord
  belongs_to :reservation

  validates :body, presence: true
end
