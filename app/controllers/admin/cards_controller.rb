class Admin::CardsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_card, only: [:edit, :update, :destroy, :mark_price_reviewed, :refresh_price]

  SORT_OPTIONS = {
    "name_asc"      => "name ASC",
    "name_desc"     => "name DESC",
    "price_asc"     => "price ASC NULLS LAST",
    "price_desc"    => "price DESC NULLS LAST",
    "edition_asc"   => "edition_name ASC, name ASC",
    "edition_desc"  => "edition_name DESC, name ASC",
    "quantity_asc"  => "quantity ASC",
    "quantity_desc" => "quantity DESC",
    "updated_desc"  => "updated_at DESC",
  }.freeze

  def index
    @cards = Card.all
    if params[:search].present?
      search = "%#{params[:search]}%"
      @cards = @cards.where("name LIKE :q OR edition_name LIKE :q", q: search)
    end
    @cards = @cards.where(edition: params[:edition]) if params[:edition].present?
    @cards = @cards.where(price: nil) if params[:no_price] == "1"
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
      render :edit, status: :unprocessable_entity
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

  def mark_price_reviewed
    @card.update_column(:price_reviewed, true)
    redirect_back fallback_location: admin_cards_path, notice: t("controllers.admin.cards.price_reviewed")
  end

  def refresh_price
    result = SingleCardPriceService.new(@card).call

    case result[:source]
    when "card_kingdom"
      redirect_back fallback_location: admin_cards_path, notice: t("controllers.admin.cards.price_refreshed_ck", price: result[:price])
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
      :quantity, :price, :foil_type
    )
  end

  def card_update_params
    params.require(:card).permit(:quantity, :foil, :price, :condition, :language)
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
