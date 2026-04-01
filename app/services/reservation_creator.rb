class ReservationCreator
  attr_reader :user, :message, :reservation, :unavailable_items

  def initialize(user, message: nil)
    @user = user
    @message = message
    @unavailable_items = []
  end

  def call
    cart_items = user.cart_items.includes(:card)

    if cart_items.empty?
      @unavailable_items = []
      return false
    end

    ActiveRecord::Base.transaction do
      # Check availability across all sellers for each cart item
      cart_items.each do |cart_item|
        card = cart_item.card
        grouped_available = card.grouped_available_quantity

        if grouped_available < cart_item.quantity
          @unavailable_items << {
            card: card,
            requested: cart_item.quantity,
            available: grouped_available
          }
        end
      end

      if @unavailable_items.any?
        raise ActiveRecord::Rollback
      end

      @reservation = user.reservations.create!(
        status: :pending,
        message: message
      )

      cart_items.each do |cart_item|
        distribute_across_sellers(cart_item.card, cart_item.quantity)
      end

      user.cart_items.destroy_all
    end

    if @unavailable_items.empty? && @reservation.present?
      ReservationMailer.created(@reservation).deliver_later
    end

    @unavailable_items.empty?
  end

  def success?
    reservation.present? && unavailable_items.empty?
  end

  private

  def distribute_across_sellers(card, total_quantity)
    # Get all sibling cards (same identity, different sellers) with available stock
    siblings = card.active_sibling_cards.where("quantity > 0").index_by(&:id)
    return if siblings.empty?

    # Pre-compute reserved quantities per card
    reserved_per_card = ReservationItem.joins(:reservation)
      .where(card_id: siblings.keys)
      .where(reservations: { status: %w[pending prepared paid] })
      .group(:card_id).sum(:quantity)

    # Build available quantity per card
    available_per_card = siblings.transform_values do |c|
      c.quantity - (reserved_per_card[c.id] || 0)
    end

    # Get stock entries for all siblings ordered by added_at (FIFO)
    entries = StockEntry.where(card_id: siblings.keys)
      .where("quantity > 0")
      .order(:added_at)

    remaining = total_quantity
    allocated_per_card = Hash.new(0)

    # Fast-forward past entries already consumed by existing reservations.
    # For each card, the oldest stock entries are considered "spoken for" first.
    consumed_per_card = reserved_per_card.transform_values(&:to_i).dup
    consumed_per_card.default = 0

    entries.each do |entry|
      break if remaining <= 0

      # Determine how much of this entry is still unconsumed by prior reservations
      entry_remaining = entry.quantity
      if consumed_per_card[entry.card_id] > 0
        skip = [consumed_per_card[entry.card_id], entry_remaining].min
        consumed_per_card[entry.card_id] -= skip
        entry_remaining -= skip
      end
      next if entry_remaining <= 0

      card_available = (available_per_card[entry.card_id] || 0) - allocated_per_card[entry.card_id]
      next if card_available <= 0

      take = [remaining, entry_remaining, card_available].min
      next if take <= 0

      allocated_per_card[entry.card_id] += take
      remaining -= take
    end

    # Create reservation items from the allocations
    allocated_per_card.each do |card_id, qty|
      next if qty <= 0
      sibling_card = siblings[card_id]
      @reservation.reservation_items.create!(
        card: sibling_card,
        quantity: qty,
        unit_price: sibling_card.price
      )
    end
  end
end
