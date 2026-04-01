class Admin::ReservationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    @reservations = Reservation.includes(:user, reservation_items: :card).order(created_at: :desc)
    if params[:status] == "all"
      # show all
    elsif params[:status] == "pending_receipt"
      @reservations = @reservations.where(status: :prepared).where.not(receipt_sent_at: nil)
    elsif params[:status].present? && Reservation.statuses.key?(params[:status])
      @reservations = @reservations.where(status: params[:status])
    else
      @reservations = @reservations.where(status: :pending)
    end
    if params[:card_name].present?
      terms = params[:card_name].strip.split(/\s+/)
      card_scope = Card.all
      terms.each { |term| card_scope = card_scope.where("cards.name LIKE ?", "%#{term}%") }
      reservation_ids = ReservationItem.joins(:card).merge(card_scope).select(:reservation_id)
      @reservations = @reservations.where(id: reservation_ids)
    end
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

  def import
    @users = User.where(admin: false).order(:name)
  end

  def create_import
    result = CardListParser.parse_and_match(params[:card_list] || "")

    if result[:matched].empty?
      redirect_to import_admin_reservations_path, alert: t("controllers.admin.reservations.import_no_matches")
      return
    end

    items = result[:matched].map do |m|
      { card_id: m[:card].id, quantity: m[:qty] }
    end

    creator = AdminReservationCreator.new(
      user_id: params.dig(:reservation, :user_id),
      guest_name: params.dig(:reservation, :guest_name),
      guest_contact: params.dig(:reservation, :guest_contact),
      message: params.dig(:reservation, :message),
      items: items
    )

    begin
      if creator.call
        # Import summary note with both list price and DB price
        summary_lines = result[:matched].map do |m|
          card = m[:card]
          foil_tag = card.foil.present? ? " (Foil)" : ""
          "- #{card.name}#{foil_tag} x#{m[:qty]} — List: $#{m[:price].to_f} | DB: $#{card.price&.to_f}"
        end
        summary_body = "Import summary:\n#{summary_lines.join("\n")}"

        if result[:unmatched].any?
          unmatched_lines = result[:unmatched].map do |u|
            reason = u[:reason] == :parse_error ? "PARSE ERROR" : "NOT FOUND"
            "- Line #{u[:line_number]}: #{u[:raw_line]} (#{reason})"
          end
          summary_body += "\n\nUnmatched cards:\n#{unmatched_lines.join("\n")}"
        end

        creator.reservation.reservation_notes.create!(body: summary_body)

        matched_count = result[:matched].size
        unmatched_count = result[:unmatched].size
        flash_msg = t("controllers.admin.reservations.import_created",
                       matched: matched_count, unmatched: unmatched_count)
        redirect_to admin_reservation_path(creator.reservation), notice: flash_msg
      else
        if creator.unavailable_items.any?
          redirect_to import_admin_reservations_path, alert: t("controllers.admin.reservations.unavailable")
        else
          redirect_to import_admin_reservations_path, alert: t("controllers.admin.reservations.no_items")
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to import_admin_reservations_path, alert: e.record.errors.full_messages.join(", ")
    end
  end

  def search_cards
    @cards = Card.search_by_name(params[:query]).limit(20)
    render partial: "card_search_results", locals: { cards: @cards }
  end

  def search_cards_for_add
    @reservation = Reservation.find(params[:id])
    @cards = Card.search_by_name(params[:query]).limit(20)
    render partial: "add_item_search_results", locals: { cards: @cards, reservation: @reservation }
  end

  def prepare
    @reservation = Reservation.find(params[:id])

    if @reservation.pending?
      @reservation.update!(status: :prepared)
      ReservationMailer.prepared(@reservation).deliver_later
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.prepared')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.prepare_error')
    end
  end

  def pay
    @reservation = Reservation.find(params[:id])

    if @reservation.prepared?
      @reservation.update!(status: :paid)
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.paid')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.pay_error')
    end
  end

  def fulfill
    @reservation = Reservation.find(params[:id])

    if @reservation.paid?
      ActiveRecord::Base.transaction do
        @reservation.update!(status: :fulfilled)
        @reservation.reservation_items.includes(:card).each do |item|
          item.card.decrement!(:quantity, item.quantity)
        end
      end
      ReservationMailer.fulfilled(@reservation).deliver_later
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.fulfilled')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.fulfill_error')
    end
  end

  def revert_to_paid
    @reservation = Reservation.find(params[:id])

    if @reservation.fulfilled?
      ActiveRecord::Base.transaction do
        if params[:restore_quantities] == "1"
          @reservation.reservation_items.includes(:card).each do |item|
            item.card.increment!(:quantity, item.quantity)
          end
        end
        @reservation.update!(status: :paid)
      end
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.reverted_to_paid')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.revert_error')
    end
  end

  def expire
    @reservation = Reservation.find(params[:id])

    if @reservation.pending? || @reservation.prepared?
      @reservation.update!(status: :expired, message: params[:message].presence)
      ReservationMailer.expired(@reservation).deliver_later
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.expired')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.expire_error')
    end
  end

  def force_decrement
    @reservation = Reservation.find(params[:id])

    unless @reservation.fulfilled?
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.force_decrement_error')
      return
    end

    ActiveRecord::Base.transaction do
      @reservation.reservation_items.includes(:card).each do |item|
        item.card.decrement!(:quantity, item.quantity)
      end
    end

    redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.force_decremented')
  end

  def toggle_trade
    @reservation = Reservation.find(params[:id])
    @reservation.update!(trade: !@reservation.trade)
    redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.trade_toggled')
  end

  def update_delivery
    @reservation = Reservation.find(params[:id])
    attrs = {
      delivery_date: params[:delivery_date].presence,
      delivery_location: params[:delivery_location].presence,
      delivery_location_other: params[:delivery_location] == "otro" ? params[:delivery_location_other].presence : nil
    }
    @reservation.update!(attrs)
    redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.delivery_updated')
  end

  def update_final_price
    @reservation = Reservation.find(params[:id])
    @reservation.update!(final_price: params[:final_price].presence)
    redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.final_price_updated')
  end

  def add_item
    @reservation = Reservation.find(params[:id])

    unless @reservation.pending? || @reservation.prepared?
      redirect_to admin_reservation_path(@reservation), alert: t("controllers.admin.reservations.add_item_error")
      return
    end

    card = Card.find(params[:card_id])
    quantity = params[:quantity].to_i
    quantity = 1 if quantity < 1

    if card.available_quantity < quantity
      redirect_to admin_reservation_path(@reservation), alert: t("controllers.admin.reservations.unavailable")
      return
    end

    existing_item = @reservation.reservation_items.find_by(card: card)
    if existing_item
      existing_item.update!(quantity: existing_item.quantity + quantity, unit_price: card.price)
    else
      @reservation.reservation_items.create!(card: card, quantity: quantity, unit_price: card.price)
    end

    redirect_to admin_reservation_path(@reservation, anchor: "items"), notice: t("controllers.admin.reservations.item_added", name: card.name)
  end

  def remove_item
    @reservation = Reservation.find(params[:id])

    unless @reservation.pending? || @reservation.prepared?
      redirect_to admin_reservation_path(@reservation), alert: t("controllers.admin.reservations.remove_item_error")
      return
    end

    item = @reservation.reservation_items.find(params[:item_id])
    item.destroy!
    redirect_to admin_reservation_path(@reservation, anchor: "items"), notice: t("controllers.admin.reservations.item_removed")
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
