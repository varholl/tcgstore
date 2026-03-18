class SingleCardPriceService
  SCRYFALL_CARD_URL = "https://api.scryfall.com/cards"

  def initialize(card)
    @card = card
  end

  def call
    # Try CK by scryfall_id first (fast, cached)
    if @card.scryfall_id.present?
      ck_price = lookup_ck_by_scryfall_id
      if ck_price
        @card.update_columns(price: ck_price, price_source: "card_kingdom")
        return { source: "card_kingdom", price: ck_price }
      end
    end

    # Fetch from Scryfall by set/collector_number
    scryfall_data = fetch_scryfall_card
    return { source: nil } unless scryfall_data

    # Update scryfall_id if needed
    scryfall_id = scryfall_data["id"]
    if scryfall_id.present? && @card.scryfall_id != scryfall_id
      @card.update_column(:scryfall_id, scryfall_id)
    end

    # Try CK with the (possibly new) scryfall_id
    if scryfall_id.present?
      ck_prices = CardKingdomPriceService.pricelist
      is_foil = @card.foil.present?
      condition = @card.condition.presence || "NM"
      ck_price = ck_prices[[scryfall_id, is_foil, condition]]
      if ck_price && ck_price > 0
        @card.update_columns(price: ck_price, price_source: "card_kingdom")
        return { source: "card_kingdom", price: ck_price }
      end
    end

    # Try CK by name + edition
    ck_by_name = CardKingdomPriceService.pricelist_by_name
    name = scryfall_data["name"]&.downcase&.strip
    edition_name = scryfall_data["set_name"]&.downcase&.strip
    if name.present? && edition_name.present?
      is_foil = @card.foil.present?
      condition = @card.condition.presence || "NM"
      collector = @card.collector_number.to_s.gsub(/\A0+/, '')
      ck_price = ck_by_name[[name, edition_name, collector, is_foil, condition]]
      if ck_price && ck_price > 0
        @card.update_columns(price: ck_price, price_source: "card_kingdom")
        return { source: "card_kingdom", price: ck_price }
      end
    end

    # Fall back to Scryfall price
    prices = scryfall_data["prices"] || {}
    price = @card.foil.present? ? prices["usd_foil"]&.to_f : prices["usd"]&.to_f
    if price && price > 0
      @card.update_columns(price: price, price_source: "scryfall", price_reviewed: false)
      return { source: "scryfall", price: price }
    end

    { source: nil }
  end

  private

  def lookup_ck_by_scryfall_id
    is_foil = @card.foil.present?
    condition = @card.condition.presence || "NM"
    CardKingdomPriceService.pricelist[[@card.scryfall_id, is_foil, condition]]
  end

  def fetch_scryfall_card
    return nil if @card.edition.blank? || @card.collector_number.blank?

    uri = URI("#{SCRYFALL_CARD_URL}/#{@card.edition}/#{@card.collector_number}")
    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError
    nil
  end
end
