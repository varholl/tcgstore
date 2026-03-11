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
    @cards = Card.where("quantity > 0")
    @cards = @cards.search_by_name(params[:search]) if params[:search].present?
    @cards = @cards.filter_by_edition(params[:edition]) if params[:edition].present?
    if params[:foil] == "foil"
      @cards = @cards.where.not(foil: [nil, ""])
    elsif params[:foil] == "non_foil"
      @cards = @cards.where(foil: [nil, ""])
    end

    if params[:sort].present? && SORT_OPTIONS.key?(params[:sort])
      sort_key = params[:sort]
      cookies[:cards_sort] = { value: sort_key, expires: 1.year.from_now }
    else
      sort_key = SORT_OPTIONS.key?(cookies[:cards_sort]) ? cookies[:cards_sort] : "price_desc"
    end
    @cards = @cards.order(Arel.sql(SORT_OPTIONS[sort_key][:order])).page(params[:page]).per(50)
    @current_sort = sort_key

    card_ids = @cards.map(&:id)
    @reserved_quantities = ReservationItem
      .joins(:reservation)
      .where(reservations: { status: %w[pending paid] }, card_id: card_ids)
      .group(:card_id)
      .sum(:quantity)

    # Hide cards with no available quantity (fully reserved)
    fully_reserved_ids = @reserved_quantities.select { |card_id, reserved|
      card = @cards.find { |c| c.id == card_id }
      card && card.quantity <= reserved
    }.keys
    @cards = @cards.where.not(id: fully_reserved_ids) if fully_reserved_ids.any?

    if params[:view].present? && %w[list grid].include?(params[:view])
      cookies[:cards_view] = { value: params[:view], expires: 1.year.from_now }
      @current_view = params[:view]
    else
      @current_view = %w[list grid].include?(cookies[:cards_view]) ? cookies[:cards_view] : "grid"
    end

    @show_how_it_works = if user_signed_in?
                           !current_user.dismissed_how_it_works
                         else
                           cookies[:dismissed_how_it_works].blank?
                         end
  end

  def dismiss_how_it_works
    if user_signed_in?
      current_user.update(dismissed_how_it_works: true)
    else
      cookies[:dismissed_how_it_works] = { value: "1", expires: 1.year.from_now }
    end
    head :ok
  end
end
