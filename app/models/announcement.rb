class Announcement < ApplicationRecord
  LEVELS = %w[info success warning danger].freeze

  validates :body, presence: true
  validates :level, inclusion: { in: LEVELS }

  # Currently displayable: active and within its (optional) schedule window.
  scope :visible, -> {
    now = Time.current
    where(active: true)
      .where("starts_at IS NULL OR starts_at <= ?", now)
      .where("ends_at IS NULL OR ends_at >= ?", now)
      .order(created_at: :desc)
  }
end
