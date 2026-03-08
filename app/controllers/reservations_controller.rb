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
      redirect_to reservation_path(creator.reservation), notice: t('controllers.reservations.created')
    else
      @cart_items = current_user.cart_items.includes(:card)
      @unavailable_items = creator.unavailable_items
      flash.now[:alert] = t('controllers.reservations.unavailable') if @unavailable_items.any?
      flash.now[:alert] = t('controllers.reservations.empty_cart') if @cart_items.empty?
      render "cart_items/index"
    end
  end

  def cancel
    @reservation = current_user.reservations.find(params[:id])

    if @reservation.pending?
      @reservation.update!(status: :cancelled)
      ReservationMailer.cancelled(@reservation).deliver_later
      redirect_to reservations_path, notice: t('controllers.reservations.cancelled')
    else
      redirect_to reservations_path, alert: t('controllers.reservations.cancel_error')
    end
  end
end
