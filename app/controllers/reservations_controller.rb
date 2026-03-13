class ReservationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @reservations = current_user.reservations.includes(:reservation_items).order(created_at: :desc).page(params[:page]).per(20)
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

    if @reservation.pending? || @reservation.prepared?
      @reservation.update!(status: :cancelled)
      ReservationMailer.cancelled(@reservation).deliver_later
      redirect_to reservations_path, notice: t('controllers.reservations.cancelled')
    else
      redirect_to reservations_path, alert: t('controllers.reservations.cancel_error')
    end
  end

  def remove_item
    @reservation = current_user.reservations.find(params[:id])

    unless @reservation.pending?
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.edit_error')
      return
    end

    item = @reservation.reservation_items.find(params[:item_id])
    item.destroy!
    ReservationMailer.updated(@reservation).deliver_later
    redirect_to reservation_path(@reservation, anchor: "items"), notice: t('controllers.reservations.item_removed')
  end

  def add_item
    @reservation = current_user.reservations.find(params[:id])

    unless @reservation.pending?
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.edit_error')
      return
    end

    card = Card.find(params[:card_id])
    quantity = params[:quantity].to_i
    quantity = 1 if quantity < 1

    if card.available_quantity < quantity
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.unavailable')
      return
    end

    existing_item = @reservation.reservation_items.find_by(card: card)
    if existing_item
      existing_item.update!(quantity: existing_item.quantity + quantity, unit_price: card.price)
    else
      @reservation.reservation_items.create!(card: card, quantity: quantity, unit_price: card.price)
    end

    ReservationMailer.updated(@reservation).deliver_later
    redirect_to reservation_path(@reservation, anchor: "items"), notice: t('controllers.reservations.item_added', name: card.name)
  end

  def search_cards
    @reservation = current_user.reservations.find(params[:id])
    @cards = Card.search_by_name(params[:query]).limit(20)
    render partial: "search_results", locals: { cards: @cards, reservation: @reservation }
  end
end
