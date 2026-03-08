class Admin::ReservationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    @reservations = Reservation.includes(:user).order(created_at: :desc)
    @reservations = @reservations.where(status: params[:status]) if params[:status].present? && Reservation.statuses.key?(params[:status])
    @reservations = @reservations.page(params[:page]).per(20)
  end

  def show
    @reservation = Reservation.includes(:user, :reservation_notes, reservation_items: :card).find(params[:id])
  end

  def new
    @reservation = Reservation.new
    @users = User.where(admin: false).order(:name)
  end

  def create
    raw_items = params.dig(:reservation, :items)
    items = (raw_items.respond_to?(:values) ? raw_items.values : Array(raw_items)).map do |item|
      { card_id: item[:card_id], quantity: item[:quantity] }
    end

    if items.empty?
      redirect_to new_admin_reservation_path, alert: t("controllers.admin.reservations.no_items")
      return
    end

    creator = AdminReservationCreator.new(
      user_id: params.dig(:reservation, :user_id),
      guest_name: params.dig(:reservation, :guest_name),
      guest_contact: params.dig(:reservation, :guest_contact),
      message: params.dig(:reservation, :message),
      items: items
    )

    if creator.call
      redirect_to admin_reservation_path(creator.reservation), notice: t("controllers.admin.reservations.created")
    else
      if creator.unavailable_items.any?
        redirect_to new_admin_reservation_path, alert: t("controllers.admin.reservations.unavailable")
      else
        redirect_to new_admin_reservation_path, alert: t("controllers.admin.reservations.no_items")
      end
    end
  end

  def search_cards
    @cards = Card.search_by_name(params[:query]).limit(20)
    render partial: "card_search_results", locals: { cards: @cards }
  end

  def pay
    @reservation = Reservation.find(params[:id])

    if @reservation.pending?
      @reservation.update!(status: :paid)
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.paid')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.pay_error')
    end
  end

  def fulfill
    @reservation = Reservation.find(params[:id])

    if @reservation.paid?
      @reservation.update!(status: :fulfilled)
      ReservationMailer.fulfilled(@reservation).deliver_later
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.fulfilled')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.fulfill_error')
    end
  end

  def expire
    @reservation = Reservation.find(params[:id])

    if @reservation.pending?
      @reservation.update!(status: :expired, message: params[:message].presence)
      ReservationMailer.expired(@reservation).deliver_later
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.expired')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.expire_error')
    end
  end

  def update_final_price
    @reservation = Reservation.find(params[:id])
    @reservation.update!(final_price: params[:final_price].presence)
    redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.final_price_updated')
  end

  def update_item_price
    @reservation = Reservation.find(params[:id])
    item = @reservation.reservation_items.find(params[:item_id])
    item.update!(unit_price: params[:unit_price])
    redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.item_price_updated')
  end

  private

  def require_admin
    redirect_to root_path, alert: t('controllers.admin.reservations.access_denied') unless current_user.admin?
  end
end
