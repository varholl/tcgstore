class CardsController < ApplicationController
  SORT_OPTIONS = {
    "name_asc"    => { order: "name ASC" },
    "name_desc"   => { order: "name DESC" },
    "price_asc"   => { order: "price ASC NULLS LAST" },
    "price_desc"  => { order: "price DESC NULLS LAST" },
    "edition_asc" => { order: "edition ASC, name ASC" },
    "edition_desc"=> { order: "edition DESC, name ASC" },
    "newest"      => { order: "last_stocked_at DESC" },
    "cmc_asc"     => { order: "cmc ASC NULLS LAST, name ASC" },
    "cmc_desc"    => { order: "cmc DESC NULLS LAST, name ASC" },
  }.freeze

  def index
    params[:search] = params[:q] if params[:search].blank? && params[:q].present?
    all_cards = Card.joins(:seller).merge(Seller.active).where("cards.quantity > 0")
    all_cards = all_cards.search_by_name(params[:search]) if params[:search].present?
    all_cards = all_cards.filter_by_edition(params[:edition]) if params[:edition].present?
    if params[:foil] == "foil"
      all_cards = all_cards.where.not(foil: [nil, ""])
    elsif params[:foil] == "non_foil"
      all_cards = all_cards.where(foil: [nil, ""])
    end
    if params[:color].present?
      if params[:color] == "colorless"
        all_cards = all_cards.where(colors: [nil, ""])
      elsif params[:color] == "multicolor"
        all_cards = all_cards.where("colors LIKE '%,%'")
      else
        all_cards = all_cards.where(colors: params[:color])
      end
    end
    if params[:card_type].present?
      all_cards = all_cards.where("card_type LIKE ?", "%#{params[:card_type]}%")
    end
    if params[:new_set] == "1"
      all_cards = all_cards.where("release_date >= ?", SiteSetting.new_set_window_days.days.ago)
    end

    # Group cards by identity (across sellers) and pick a representative per group
    all_cards_loaded = all_cards.to_a
    all_card_ids = all_cards_loaded.map(&:id)

    reserved_by_card = ReservationItem
      .joins(:reservation)
      .where(reservations: { status: %w[pending in_preparation prepared paid shipped] }, card_id: all_card_ids)
      .group(:card_id)
      .sum(:quantity)

    groups = all_cards_loaded.group_by(&:card_identity)

    @available_quantities = {}
    representatives = []

    groups.each do |_identity, cards|
      total_qty = cards.sum(&:quantity)
      total_reserved = cards.sum { |c| reserved_by_card[c.id] || 0 }
      available = total_qty - total_reserved

      next if available <= 0

      representative = cards.min_by { |c| c.last_stocked_at || Time.at(0) }
      @available_quantities[representative.id] = available
      representatives << representative
    end

    # Sort
    if params[:sort].present? && SORT_OPTIONS.key?(params[:sort])
      sort_key = params[:sort]
      cookies[:cards_sort] = { value: sort_key, expires: 1.year.from_now }
    else
      sort_key = SORT_OPTIONS.key?(cookies[:cards_sort]) ? cookies[:cards_sort] : "price_desc"
    end
    @current_sort = sort_key

    representatives = sort_cards(representatives, sort_key)

    @cards = Kaminari.paginate_array(representatives).page(params[:page]).per(50)

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

  def show
    card_id = params[:id].presence
    @card = Card.where(id: card_id).first if card_id.present?

    if @card.nil?
      render :not_found, status: :not_found
      return
    end

    @card_available = @card.available_quantity

    # All other listings with the same name (any printing/finish/condition) except the current card
    listings = Card.where(name: @card.name)
      .where.not(id: @card.id)
      .joins(:seller).merge(Seller.active)
      .where("cards.quantity > 0")
      .to_a

    reserved_by_card = ReservationItem
      .joins(:reservation)
      .where(reservations: { status: %w[pending in_preparation prepared paid shipped] }, card_id: listings.map(&:id))
      .group(:card_id)
      .sum(:quantity)

    @available_quantities = {}
    @listings = []
    listings.group_by(&:card_identity).each do |_identity, group|
      total_qty = group.sum(&:quantity)
      total_reserved = group.sum { |c| reserved_by_card[c.id] || 0 }
      available = total_qty - total_reserved
      next if available <= 0

      representative = group.min_by { |c| c.price || Float::INFINITY }
      @available_quantities[representative.id] = available
      @listings << representative
    end
    @listings.sort_by! { |c| c.price || Float::INFINITY }
  end

  def dismiss_how_it_works
    if user_signed_in?
      current_user.update(dismissed_how_it_works: true)
    else
      cookies[:dismissed_how_it_works] = { value: "1", expires: 1.year.from_now }
    end
    head :ok
  end

  private

  def sort_cards(cards, sort_key)
    case sort_key
    when "name_asc"     then cards.sort_by { |c| c.name.to_s }
    when "name_desc"    then cards.sort_by { |c| c.name.to_s }.reverse
    when "price_asc"    then cards.sort_by { |c| c.price || Float::INFINITY }
    when "price_desc"   then cards.sort_by { |c| -(c.price || 0) }
    when "edition_asc"  then cards.sort_by { |c| [c.edition.to_s, c.name.to_s] }
    when "edition_desc" then cards.sort_by { |c| c.edition.to_s }.reverse
    when "newest"       then cards.sort_by { |c| c.last_stocked_at || Time.at(0) }.reverse
    when "cmc_asc"      then cards.sort_by { |c| [c.cmc || Float::INFINITY, c.name.to_s] }
    when "cmc_desc"     then cards.sort_by { |c| [-(c.cmc || 0), c.name.to_s] }
    else cards.sort_by { |c| -(c.price || 0) }
    end
  end
end
