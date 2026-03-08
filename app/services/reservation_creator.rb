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
      cart_items.each do |cart_item|
        card = cart_item.card
        available = card.available_quantity

        if available < cart_item.quantity
          @unavailable_items << {
            card: card,
            requested: cart_item.quantity,
            available: available
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
        @reservation.reservation_items.create!(
          card: cart_item.card,
          quantity: cart_item.quantity,
          unit_price: cart_item.card.price
        )
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
end
