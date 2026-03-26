class AdminReservationCreator
  attr_reader :params, :reservation, :unavailable_items

  def initialize(params)
    @params = params
    @unavailable_items = []
  end

  def call
    items = params[:items] || []
    return false if items.empty?

    ActiveRecord::Base.transaction do
      items.each do |item|
        card = Card.find(item[:card_id])
        available = card.grouped_available_quantity

        if available < item[:quantity].to_i
          @unavailable_items << {
            card: card,
            requested: item[:quantity].to_i,
            available: available
          }
        end
      end

      if @unavailable_items.any?
        raise ActiveRecord::Rollback
      end

      @reservation = Reservation.create!(
        user_id: params[:user_id].presence,
        guest_name: params[:guest_name],
        guest_contact: params[:guest_contact],
        message: params[:message],
        status: :pending
      )

      items.each do |item|
        card = Card.find(item[:card_id])
        distribute_across_sellers(card, item[:quantity].to_i)
      end
    end

    if @unavailable_items.empty? && @reservation.present?
      ReservationMailer.created(@reservation).deliver_later
    end

    @unavailable_items.empty?
  end

  private

  def distribute_across_sellers(card, total_quantity)
    siblings = card.sibling_cards.where("quantity > 0").index_by(&:id)
    return if siblings.empty?

    reserved_per_card = ReservationItem.joins(:reservation)
      .where(card_id: siblings.keys)
      .where(reservations: { status: %w[pending prepared paid] })
      .group(:card_id).sum(:quantity)

    available_per_card = siblings.transform_values do |c|
      c.quantity - (reserved_per_card[c.id] || 0)
    end

    entries = StockEntry.where(card_id: siblings.keys)
      .where("quantity > 0")
      .order(:added_at)

    remaining = total_quantity
    allocated_per_card = Hash.new(0)

    consumed_per_card = reserved_per_card.transform_values(&:to_i).dup
    consumed_per_card.default = 0

    entries.each do |entry|
      break if remaining <= 0

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
