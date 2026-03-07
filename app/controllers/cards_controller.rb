class CardsController < ApplicationController
  SORT_OPTIONS = {
    "name_asc"    => { order: "name ASC" },
    "name_desc"   => { order: "name DESC" },
    "price_asc"   => { order: "price ASC NULLS LAST" },
    "price_desc"  => { order: "price DESC NULLS LAST" },
    "edition_asc" => { order: "edition ASC, name ASC" },
    "edition_desc"=> { order: "edition DESC, name ASC" },
  }.freeze

  def index
    @cards = Card.all
    @cards = @cards.search_by_name(params[:search]) if params[:search].present?
    @cards = @cards.filter_by_edition(params[:edition]) if params[:edition].present?

    sort_key = SORT_OPTIONS.key?(params[:sort]) ? params[:sort] : "name_asc"
    @cards = @cards.order(Arel.sql(SORT_OPTIONS[sort_key][:order])).page(params[:page]).per(50)
    @current_sort = sort_key

    card_ids = @cards.map(&:id)
    @reserved_quantities = ReservationItem
      .joins(:reservation)
      .where(reservations: { status: "pending" }, card_id: card_ids)
      .group(:card_id)
      .sum(:quantity)
  end
end
