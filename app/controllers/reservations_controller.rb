class ReservationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @reservations = current_user.reservations.order(created_at: :desc).page(params[:page]).per(20)
  end

  def show
    @reservation = current_user.reservations.includes(reservation_items: :card).find(params[:id])
  end

  def create
    creator = ReservationCreator.new(current_user, message: params[:message])

    if creator.call
      redirect_to reservation_path(creator.reservation), notice: "Reservation request submitted successfully!"
    else
      @cart_items = current_user.cart_items.includes(:card)
      @unavailable_items = creator.unavailable_items
      flash.now[:alert] = "Some items are not available in the requested quantity." if @unavailable_items.any?
      flash.now[:alert] = "Your cart is empty." if @cart_items.empty?
      render "cart_items/index"
    end
  end

  def cancel
    @reservation = current_user.reservations.find(params[:id])

    if @reservation.pending?
      @reservation.update!(status: :cancelled)
      redirect_to reservations_path, notice: "Reservation cancelled."
    else
      redirect_to reservations_path, alert: "Only pending reservations can be cancelled."
    end
  end
end
