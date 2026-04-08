module Api
  class CardsController < BaseController
    MAX_PER_PAGE = 100
    DEFAULT_PER_PAGE = 50

    def index
      query = params[:q].presence || params[:search].presence

      scope = Card.joins(:seller).merge(Seller.active).where("cards.quantity > 0")
      scope = scope.search_by_name(query) if query.present?

      per_page = [(params[:per_page].presence || DEFAULT_PER_PAGE).to_i, MAX_PER_PAGE].min
      per_page = DEFAULT_PER_PAGE if per_page <= 0
      page = [params[:page].to_i, 1].max

      all_cards = scope.to_a

      reserved_by_card = ReservationItem
        .joins(:reservation)
        .where(reservations: { status: %w[pending prepared paid shipped] }, card_id: all_cards.map(&:id))
        .group(:card_id)
        .sum(:quantity)

      grouped = all_cards.group_by(&:card_identity).filter_map do |_identity, cards|
        total_qty = cards.sum(&:quantity)
        total_reserved = cards.sum { |c| reserved_by_card[c.id] || 0 }
        available = total_qty - total_reserved
        next if available <= 0

        representative = cards.min_by { |c| c.last_stocked_at || Time.at(0) }

        {
          id: representative.id,
          title: representative.name,
          price: representative.price,
          imageUrl: nil,
          condition: representative.condition,
          expansion: representative.edition_name.presence || representative.edition,
          foil: representative.foil.present? ? "si" : "no",
          language: representative.language,
          scryfall_id: representative.scryfall_id,
          quantity: available
        }
      end

      grouped.sort_by! { |r| [r[:title].to_s, r[:id]] }

      paged = grouped[((page - 1) * per_page), per_page] || []

      render json: { data: paged, page: page, per_page: per_page, total: grouped.size }
    end
  end
end
