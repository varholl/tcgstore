class Admin::CardsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_card, only: [:edit, :update, :destroy]

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
    @pending_reserved = @card.reservation_items
      .joins(:reservation)
      .where(reservations: { status: "pending" })
      .sum(:quantity)
  end

  def update
    if @card.update(card_update_params)
      redirect_to admin_cards_path, notice: t("controllers.admin.cards.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @card.reservation_items.exists?
      redirect_to admin_cards_path, alert: t("controllers.admin.cards.cannot_delete_with_reservations")
    else
      @card.destroy!
      redirect_to admin_cards_path, notice: t("controllers.admin.cards.deleted")
    end
  end

  def refresh_prices
    CardPriceRefreshJob.perform_later
    redirect_to admin_cards_path, notice: t("controllers.admin.cards.prices_refresh_started")
  end

  def search_scryfall
    results = ScryfallSearchService.new(params[:query]).call

    scryfall_ids = results.map { |c| c[:scryfall_id] }
    ck_prices = CardKingdomPriceService.lookup_batch(scryfall_ids)

    results.each do |card|
      sid = card[:scryfall_id]
      card[:ck_price] = ck_prices[[sid, false]]
      card[:ck_price_foil] = ck_prices[[sid, true]]
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
      :quantity, :price
    )
  end

  def card_update_params
    params.require(:card).permit(:quantity, :foil, :price)
  end

  def require_admin
    redirect_to root_path, alert: t("controllers.admin.cards.access_denied") unless current_user.admin?
  end
end
