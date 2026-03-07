class CardsController < ApplicationController
  SORT_OPTIONS = {
    "name_asc"    => { name: "Name (A-Z)",           order: "name ASC" },
    "name_desc"   => { name: "Name (Z-A)",           order: "name DESC" },
    "price_asc"   => { name: "Price (Low to High)",  order: "price ASC NULLS LAST" },
    "price_desc"  => { name: "Price (High to Low)",  order: "price DESC NULLS LAST" },
    "edition_asc" => { name: "Edition (A-Z)",        order: "edition ASC, name ASC" },
    "edition_desc"=> { name: "Edition (Z-A)",        order: "edition DESC, name ASC" },
  }.freeze

  def index
    @cards = Card.all
    @cards = @cards.search_by_name(params[:search]) if params[:search].present?
    @cards = @cards.filter_by_edition(params[:edition]) if params[:edition].present?

    sort_key = SORT_OPTIONS.key?(params[:sort]) ? params[:sort] : "name_asc"
    @cards = @cards.order(Arel.sql(SORT_OPTIONS[sort_key][:order])).page(params[:page]).per(50)
    @current_sort = sort_key
  end
end
