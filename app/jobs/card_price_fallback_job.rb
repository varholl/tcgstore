class CardPriceFallbackJob < ApplicationJob
  queue_as :default

  SCRYFALL_CARD_URL = "https://api.scryfall.com/cards"
  SCRYFALL_DELAY = 0.1 # 100ms between requests per Scryfall guidelines

  def perform
    ck_by_name = CardKingdomPriceService.pricelist_by_name
    ck_updated_cards = []
    scryfall_updated_cards = []
    tcgplayer_updated_cards = []
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
      when "tcgplayer"
        card.update_columns(price: result[:price], price_source: "tcgplayer")
        tcgplayer_updated_cards << card
      when "scryfall"
        card.update_columns(price: result[:price], price_source: "scryfall", price_reviewed: false)
        scryfall_updated_cards << card
      else
        not_found_cards << card
      end
    end

    Rails.cache.delete(CardKingdomPriceService::CACHE_KEY_BY_NAME)

    CardPriceMailer.fallback_results(ck_updated_cards, scryfall_updated_cards, tcgplayer_updated_cards, not_found_cards).deliver_later
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

    prices = data["prices"] || {}
    scryfall_price = card.foil.present? ? prices["usd_foil"]&.to_f : prices["usd"]&.to_f
    scryfall_price = nil unless scryfall_price && scryfall_price > 0

    # New-set cards: take the higher of CK and TCGPlayer to protect margin against
    # stale CK prices on fresh releases. Fall back to Scryfall if neither has it.
    if card.from_new_set?
      ck_price = find_ck_price(card, data, ck_by_name)
      tcg_price = TcgplayerPriceService.lookup(data["tcgplayer_id"], foil: card.foil.present?)
      tcg_price ||= TcgplayerPriceService.lookup_by_search(
        name: data["name"],
        set_name: data["set_name"],
        collector_number: card.collector_number,
        foil: card.foil.present?
      )

      if ck_price && tcg_price
        return tcg_price > ck_price ? { price: tcg_price, source: "tcgplayer" } : { price: ck_price, source: "card_kingdom" }
      end
      return { price: tcg_price, source: "tcgplayer" } if tcg_price
      return { price: ck_price, source: "card_kingdom" } if ck_price
      return { price: scryfall_price, source: "scryfall" } if scryfall_price
      return nil
    end

    # Default order: CK by name + edition + foil + condition, then Scryfall.
    ck_price = find_ck_price(card, data, ck_by_name)
    return { price: ck_price, source: "card_kingdom" } if ck_price
    return { price: scryfall_price, source: "scryfall" } if scryfall_price

    nil
  rescue StandardError
    nil
  end

  def find_ck_price(card, scryfall_data, ck_by_name)
    is_foil = card.foil.present?
    condition = card.condition.presence || "NM"

    # Try CK by scryfall_id first — most reliable, avoids set-name mismatches
    # like CK's "Secrets of Strixhaven Commander Decks" vs Scryfall's "Secrets of Strixhaven Commander".
    scryfall_id = scryfall_data["id"]
    if scryfall_id.present?
      price = CardKingdomPriceService.pricelist[[scryfall_id, is_foil, condition]]
      return price if price && price > 0
    end

    name = scryfall_data["name"]&.downcase&.strip
    return nil if name.blank?

    collector = CardKingdomPriceService.normalize_collector(card.collector_number)
    edition_name = scryfall_data["set_name"]&.downcase&.strip
    return nil if edition_name.blank?

    price = ck_by_name[[name, edition_name, collector, is_foil, condition]]
    return price if price && price > 0

    # Japanese prints: CK lists them under "<edition> jpn" with matching collector numbers.
    if card.language.to_s.casecmp?("japanese")
      price = ck_by_name[[name, "#{edition_name} jpn", collector, is_foil, condition]]
      return price if price && price > 0
    end

    # Try "promotional" edition (CK lists many promos under this edition)
    price = ck_by_name[[name, "promotional", collector, is_foil, condition]]
    return price if price && price > 0

    nil
  end
end
