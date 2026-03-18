class CardPriceFallbackJob < ApplicationJob
  queue_as :default

  SCRYFALL_CARD_URL = "https://api.scryfall.com/cards"
  SCRYFALL_DELAY = 0.1 # 100ms between requests per Scryfall guidelines

  def perform
    ck_by_name = CardKingdomPriceService.pricelist_by_name
    ck_updated_cards = []
    scryfall_updated_cards = []
    not_found_cards = []

    Card.where(price_source: nil)
        .where.not(edition: [nil, ""])
        .where.not(collector_number: [nil, ""])
        .find_each do |card|

      sleep(SCRYFALL_DELAY)
      result = lookup_card(card, ck_by_name)

      case result&.dig(:source)
      when "card_kingdom"
        card.update_columns(price: result[:price], price_source: "card_kingdom")
        ck_updated_cards << card
      when "scryfall"
        card.update_columns(price: result[:price], price_source: "scryfall", price_reviewed: false)
        scryfall_updated_cards << card
      else
        not_found_cards << card
      end
    end

    Rails.cache.delete(CardKingdomPriceService::CACHE_KEY_BY_NAME)

    CardPriceMailer.fallback_results(ck_updated_cards, scryfall_updated_cards, not_found_cards).deliver_later
  end

  private

  def lookup_card(card, ck_by_name)
    uri = URI("#{SCRYFALL_CARD_URL}/#{card.edition}/#{card.collector_number}")
    response = Net::HTTP.get_response(uri)

    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)

    # Update scryfall_id if we got one
    scryfall_id = data["id"]
    if scryfall_id.present? && card.scryfall_id != scryfall_id
      card.update_column(:scryfall_id, scryfall_id)
    end

    # Try Card Kingdom by name + edition + foil + condition
    ck_price = find_ck_price(card, data, ck_by_name)
    return { price: ck_price, source: "card_kingdom" } if ck_price

    # Fall back to Scryfall price
    prices = data["prices"] || {}
    price = card.foil.present? ? prices["usd_foil"]&.to_f : prices["usd"]&.to_f
    return { price: price, source: "scryfall" } if price && price > 0

    nil
  rescue StandardError
    nil
  end

  def find_ck_price(card, scryfall_data, ck_by_name)
    name = scryfall_data["name"]&.downcase&.strip
    return nil if name.blank?

    is_foil = card.foil.present?
    condition = card.condition.presence || "NM"
    collector = card.collector_number.to_s.gsub(/\A0+/, '')

    edition_name = scryfall_data["set_name"]&.downcase&.strip
    return nil if edition_name.blank?

    price = ck_by_name[[name, edition_name, collector, is_foil, condition]]
    return price if price && price > 0

    nil
  end
end
