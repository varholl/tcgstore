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
        available = card.available_quantity

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
        @reservation.reservation_items.create!(
          card_id: card.id,
          quantity: item[:quantity].to_i,
          unit_price: card.price
        )
      end
    end

    if @unavailable_items.empty? && @reservation.present?
      ReservationMailer.created(@reservation).deliver_later
    end

    @unavailable_items.empty?
  end
end
