require "ostruct"

class ReservationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_no_maintenance!, only: [:create, :add_item]

  def index
    @reservations = current_user.reservations.includes(:reservation_items).order(created_at: :desc).page(params[:page]).per(20)
  end

  def show
    @reservation = current_user.reservations.includes(reservation_items: { card: :seller }).find(params[:id])

    unless admin_or_seller?
      @grouped_items = @reservation.reservation_items.group_by { |i| i.card.card_identity }.map do |_identity, items|
        representative = items.first
        ::OpenStruct.new(
          card: representative.card,
          quantity: items.sum(&:quantity),
          unit_price: representative.unit_price,
          id: representative.id
        )
      end
    end
  end

  def create
    unless Reservation::SHIPPING_METHODS.include?(params[:shipping_method])
      @cart_items = current_user.cart_items.includes(:card)
      @available_quantities = @cart_items.each_with_object({}) { |ci, h| h[ci.card_id] = ci.card.available_quantity }
      flash.now[:alert] = t('controllers.reservations.shipping_required')
      render "cart_items/index"
      return
    end

    attr = current_attribution || {}
    creator = ReservationCreator.new(
      current_user,
      message: params[:message],
      shipping_method: params[:shipping_method],
      pickup_location: params[:pickup_location],
      source: attr[:source],
      campaign: attr[:campaign],
      referrer: attr[:referrer]
    )

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

    representative = @reservation.reservation_items.find(params[:item_id])

    if admin_or_seller?
      representative.destroy!
      @reservation.reload
      ReservationMailer.updated(@reservation).deliver_later

      respond_to do |format|
        format.turbo_stream do
          total = @reservation.reservation_items.sum { |i| (i.unit_price || 0) * i.quantity }
          render turbo_stream: [
            turbo_stream.remove(representative),
            turbo_stream.replace("reservation_total",
              html: "<tr id=\"reservation_total\"><td colspan=\"7\" class=\"text-end\"><strong>#{t('reservations.total')}</strong></td><td><strong>#{helpers.number_to_currency(total)}</strong></td></tr>".html_safe
            )
          ]
        end
        format.html do
          redirect_to reservation_path(@reservation, view: params[:view], anchor: "items"), notice: t('controllers.reservations.item_removed')
        end
      end
    else
      identity = representative.card.card_identity
      @reservation.reservation_items.includes(:card).select { |i| i.card.card_identity == identity }.each(&:destroy!)
      @reservation.reload
      ReservationMailer.updated(@reservation).deliver_later

      redirect_to reservation_path(@reservation, view: params[:view], anchor: "items"), notice: t('controllers.reservations.item_removed')
    end
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

  def set_payment_method
    @reservation = current_user.reservations.find(params[:id])

    unless @reservation.prepared?
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.edit_error')
      return
    end

    payment_method = params[:payment_method]
    if %w[cash transfer].include?(payment_method)
      @reservation.update!(payment_method: payment_method)
      redirect_to reservation_path(@reservation), notice: t('controllers.reservations.payment_method_set')
    else
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.invalid_payment_method')
    end
  end

  def upload_receipt
    @reservation = current_user.reservations.find(params[:id])

    unless @reservation.prepared? && @reservation.payment_method == "transfer"
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.edit_error')
      return
    end

    file = params[:receipt]
    unless file.is_a?(ActionDispatch::Http::UploadedFile)
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.receipt_missing')
      return
    end

    allowed_types = %w[image/jpeg image/png image/webp application/pdf]
    unless allowed_types.include?(file.content_type)
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.receipt_invalid_type')
      return
    end

    ReservationMailer.transfer_receipt(@reservation, file).deliver_now
    @reservation.update!(receipt_sent_at: Time.current)
    redirect_to reservation_path(@reservation), notice: t('controllers.reservations.receipt_sent')
  end

  def update_shipping_method
    @reservation = current_user.reservations.find(params[:id])

    unless @reservation.pending? || @reservation.prepared? || @reservation.paid?
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.edit_error')
      return
    end

    shipping_method = params[:shipping_method]
    unless Reservation::SHIPPING_METHODS.include?(shipping_method)
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.shipping_required')
      return
    end

    attrs = { shipping_method: shipping_method }
    if shipping_method == "store_pickup"
      attrs[:pickup_location] = params[:pickup_location] if Reservation::PICKUP_LOCATIONS.include?(params[:pickup_location])
    else
      attrs[:pickup_location] = nil
    end

    @reservation.update!(attrs)
    redirect_to reservation_path(@reservation), notice: t('controllers.reservations.shipping_method_updated')
  end

  def update_shipping_info
    @reservation = current_user.reservations.find(params[:id])

    unless @reservation.pending? || @reservation.prepared? || @reservation.paid?
      redirect_to reservation_path(@reservation), alert: t('controllers.reservations.edit_error')
      return
    end

    user_ok = current_user.update(personal_info_params)
    address = current_user.addresses.first || current_user.addresses.build
    addr_ok = address.update(address_params)

    if user_ok && addr_ok
      redirect_to reservation_path(@reservation), notice: t('controllers.reservations.shipping_info_saved')
    else
      @reservation = current_user.reservations.includes(reservation_items: { card: :seller }).find(params[:id])
      unless admin_or_seller?
        @grouped_items = @reservation.reservation_items.group_by { |i| i.card.card_identity }.map do |_identity, items|
          representative = items.first
          ::OpenStruct.new(
            card: representative.card,
            quantity: items.sum(&:quantity),
            unit_price: representative.unit_price,
            id: representative.id
          )
        end
      end
      errors = current_user.errors.full_messages + address.errors.full_messages
      flash.now[:alert] = errors.join(", ")
      render :show, status: :unprocessable_entity
    end
  end

  def search_cards
    @reservation = current_user.reservations.find(params[:id])
    @cards = Card.search_by_name(params[:query]).limit(20)
    render partial: "search_results", locals: { cards: @cards, reservation: @reservation }
  end

  private

  def personal_info_params
    params.require(:user).permit(:name, :phone_number, :dni)
  end

  def address_params
    params.require(:address).permit(:address, :address_number, :zipcode, :city, :province, :between_streets)
  end
end
