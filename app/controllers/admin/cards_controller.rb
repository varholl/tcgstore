class Admin::CardsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_card, only: [:edit, :update, :destroy, :mark_price_reviewed, :refresh_price, :add_stock, :remove_stock_entry]

  LANGUAGES = %w[English Spanish Japanese Italian Portuguese].freeze

  SORT_OPTIONS = {
    "name_asc"       => "name ASC",
    "name_desc"      => "name DESC",
    "price_asc"      => "price ASC NULLS LAST",
    "price_desc"     => "price DESC NULLS LAST",
    "edition_asc"    => "edition_name ASC, name ASC",
    "edition_desc"   => "edition_name DESC, name ASC",
    "collector_asc"  => "CAST(collector_number AS INTEGER) ASC, collector_number ASC",
    "collector_desc" => "CAST(collector_number AS INTEGER) DESC, collector_number DESC",
    "quantity_asc"   => "quantity ASC",
    "quantity_desc"  => "quantity DESC",
    "updated_desc"   => "updated_at DESC",
  }.freeze

  def index
    @sellers = Seller.order(:name)
    @cards = Card.includes(:seller)
    if params[:search].present?
      params[:search].strip.split(/\s+/).each do |term|
        pattern = "%#{term}%"
        @cards = @cards.where("name LIKE :q OR edition_name LIKE :q", q: pattern)
      end
    end
    @cards = @cards.where(edition: params[:edition]) if params[:edition].present?
    @cards = @cards.where(price: nil) if params[:no_price] == "1"
    @cards = @cards.where(seller_id: params[:seller_id]) if params[:seller_id].present?
    if params[:price_source] == "needs_review"
      @cards = @cards.where(price_source: "scryfall", price_reviewed: false)
    elsif params[:price_source].present?
      @cards = @cards.where(price_source: params[:price_source])
    end

    sort_key = SORT_OPTIONS.key?(params[:sort]) ? params[:sort] : "updated_desc"
    @cards = @cards.order(Arel.sql(SORT_OPTIONS[sort_key]))
    @current_sort = sort_key

    @cards = @cards.page(params[:page]).per(20)
  end

  def new
    @sellers = Seller.all
  end

  def create
    adder = AdminCardStockAdder.new(card_params)
    case adder.call
    when :added
      redirect_to admin_cards_path, notice: t("controllers.admin.cards.added")
    when :incremented
      redirect_to admin_cards_path, notice: t("controllers.admin.cards.incremented")
    else
      redirect_to new_admin_card_path, alert: adder.card&.errors&.full_messages&.join(", ") || t("controllers.admin.cards.error")
    end
  end

  def edit
    @return_to = request.referer
    @pending_reserved = @card.reservation_items
      .joins(:reservation)
      .where(reservations: { status: "pending" })
      .sum(:quantity)
    @stock_entries = @card.stock_entries.order(added_at: :desc)
    @active_reservations = Reservation.joins(:reservation_items)
      .where(reservation_items: { card_id: @card.id })
      .where(status: %w[pending prepared paid shipped fulfilled])
      .distinct
      .order(created_at: :desc)
  end

  def update
    if @card.update(card_update_params)
      redirect_to safe_return_path, notice: t("controllers.admin.cards.updated")
    else
      @return_to = params[:return_to]
      @pending_reserved = @card.reservation_items
        .joins(:reservation)
        .where(reservations: { status: "pending" })
        .sum(:quantity)
      @stock_entries = @card.stock_entries.order(added_at: :desc)
      @active_reservations = Reservation.joins(:reservation_items)
        .where(reservation_items: { card_id: @card.id })
        .where(status: %w[pending prepared paid shipped fulfilled])
        .distinct
        .order(created_at: :desc)
      render :edit, status: :unprocessable_entity
    end
  end

  def add_stock
    qty = params[:stock_quantity].to_i
    if qty > 0
      now = Time.current
      @card.increment!(:quantity, qty)
      @card.update_column(:last_stocked_at, now)
      @card.stock_entries.create!(quantity: qty, added_at: now)
      redirect_to edit_admin_card_path(@card, return_to: params[:return_to]), notice: t("controllers.admin.cards.stock_added", count: qty)
    else
      redirect_to edit_admin_card_path(@card, return_to: params[:return_to]), alert: t("controllers.admin.cards.stock_invalid_quantity")
    end
  end

  def remove_stock_entry
    entry = @card.stock_entries.find(params[:stock_entry_id])
    protected_reserved = @card.reservation_items.joins(:reservation)
      .where(reservations: { status: %w[prepared paid] })
      .sum(:quantity)
    remaining_quantity = @card.quantity - entry.quantity

    if remaining_quantity < protected_reserved
      redirect_to edit_admin_card_path(@card, return_to: params[:return_to]),
        alert: t("controllers.admin.cards.stock_remove_protected", count: protected_reserved)
    else
      ActiveRecord::Base.transaction do
        @card.decrement!(:quantity, entry.quantity)
        entry.destroy!
      end
      redirect_to edit_admin_card_path(@card, return_to: params[:return_to]),
        notice: t("controllers.admin.cards.stock_removed", count: entry.quantity)
    end
  end

  def destroy
    if @card.reservation_items.exists?
      redirect_back fallback_location: admin_cards_path, alert: t("controllers.admin.cards.cannot_delete_with_reservations")
    else
      @card.destroy!
      redirect_back fallback_location: admin_cards_path, notice: t("controllers.admin.cards.deleted")
    end
  end

  def refresh_prices
    CardPriceRefreshJob.perform_later
    redirect_to admin_cards_path, notice: t("controllers.admin.cards.prices_refresh_started")
  end

  def fetch_metadata
    CardMetadataFetchJob.perform_later
    redirect_to admin_cards_path, notice: t("controllers.admin.cards.metadata_fetch_started")
  end

  def bulk_update_language
    ids = Array(params[:card_ids]).reject(&:blank?)
    language = params[:language].to_s

    if ids.empty?
      redirect_back fallback_location: admin_cards_path, alert: t("controllers.admin.cards.bulk_no_selection")
      return
    end

    unless LANGUAGES.include?(language)
      redirect_back fallback_location: admin_cards_path, alert: t("controllers.admin.cards.bulk_invalid_language")
      return
    end

    count = Card.where(id: ids).update_all(language: language)
    redirect_back fallback_location: admin_cards_path, notice: t("controllers.admin.cards.bulk_language_updated", count: count, language: t("languages.#{language.downcase}"))
  end

  def mark_price_reviewed
    @card.update_column(:price_reviewed, true)
    redirect_back fallback_location: admin_cards_path, notice: t("controllers.admin.cards.price_reviewed")
  end

  def refresh_price
    result = SingleCardPriceService.new(@card).call

    case result[:source]
    when "card_kingdom"
      redirect_back fallback_location: admin_cards_path, notice: t("controllers.admin.cards.price_refreshed_ck", price: result[:price])
    when "tcgplayer"
      redirect_back fallback_location: admin_cards_path, notice: t("controllers.admin.cards.price_refreshed_tcgplayer", price: result[:price])
    when "scryfall"
      redirect_back fallback_location: admin_cards_path, notice: t("controllers.admin.cards.price_refreshed_scryfall", price: result[:price])
    else
      redirect_back fallback_location: admin_cards_path, alert: t("controllers.admin.cards.price_refresh_failed")
    end
  end

  def search_scryfall
    results = ScryfallSearchService.new(params[:query]).call

    scryfall_ids = results.map { |c| c[:scryfall_id] }
    ck_prices = CardKingdomPriceService.lookup_batch(scryfall_ids)

    conditions = %w[NM LP MP HP DMG]
    results.each do |card|
      sid = card[:scryfall_id]
      # NM price for display (backward compat)
      card[:ck_price] = ck_prices[[sid, false, "NM"]]
      card[:ck_price_foil] = ck_prices[[sid, true, "NM"]]
      # Per-condition prices for JS
      card[:ck_condition_prices] = {}
      card[:ck_condition_prices_foil] = {}
      conditions.each do |cond|
        card[:ck_condition_prices][cond] = ck_prices[[sid, false, cond]]
        card[:ck_condition_prices_foil][cond] = ck_prices[[sid, true, cond]]
      end
    end

    render partial: "scryfall_results", locals: { results: results }
  end

  private

  def set_card
    @card = Card.find(params[:id])
  end

  def card_params
    params.permit(
      :name, :scryfall_id, :set_code, :set_name,
      :collector_number, :condition, :language, :foil,
      :quantity, :price, :foil_type, :seller_id,
      :colors, :mana_cost, :cmc, :card_type, :card_subtype, :rarity, :release_date
    )
  end

  def card_update_params
    params.require(:card).permit(:foil, :price, :condition, :language, :release_date)
  end

  def safe_return_path
    return_to = params[:return_to]
    if return_to.present? && return_to.start_with?("/")
      return_to
    else
      admin_cards_path
    end
  end

  def require_admin
    redirect_to root_path, alert: t("controllers.admin.cards.access_denied") unless current_user.admin?
  end
end
