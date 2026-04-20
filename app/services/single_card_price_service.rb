class SingleCardPriceService
  SCRYFALL_CARD_URL = "https://api.scryfall.com/cards"

  def initialize(card)
    @card = card
  end

  def call
    return new_set_lookup if @card.from_new_set?

    # Try CK by scryfall_id first (fast, cached)
    if @card.scryfall_id.present?
      ck_price = lookup_ck_by_scryfall_id(@card.scryfall_id)
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
      ck_price = lookup_ck_by_scryfall_id(scryfall_id)
      if ck_price
        @card.update_columns(price: ck_price, price_source: "card_kingdom")
        return { source: "card_kingdom", price: ck_price }
      end
    end

    # Try CK by name + edition
    ck_price = lookup_ck_by_name(scryfall_data)
    if ck_price
      @card.update_columns(price: ck_price, price_source: "card_kingdom")
      return { source: "card_kingdom", price: ck_price }
    end

    # Fall back to Scryfall price
    scryfall_price = extract_scryfall_price(scryfall_data)
    if scryfall_price
      @card.update_columns(price: scryfall_price, price_source: "scryfall", price_reviewed: false)
      return { source: "scryfall", price: scryfall_price }
    end

    { source: nil }
  end

  private

  # New-set cards: take the higher of CK and TCGPlayer to protect margin against
  # stale CK prices on fresh releases. Fall back to Scryfall if neither has it.
  def new_set_lookup
    scryfall_data = fetch_scryfall_card
    return { source: nil } unless scryfall_data

    scryfall_id = scryfall_data["id"]
    if scryfall_id.present? && @card.scryfall_id != scryfall_id
      @card.update_column(:scryfall_id, scryfall_id)
    end

    ck_price = lookup_ck_by_scryfall_id(scryfall_id) if scryfall_id.present?
    ck_price ||= lookup_ck_by_name(scryfall_data)
    tcg_price = TcgplayerPriceService.lookup(scryfall_data["tcgplayer_id"], foil: @card.foil.present?)
    tcg_price ||= TcgplayerPriceService.lookup_by_search(
      name: scryfall_data["name"],
      set_name: scryfall_data["set_name"],
      collector_number: @card.collector_number,
      foil: @card.foil.present?
    )

    winner =
      if ck_price && tcg_price
        tcg_price > ck_price ? [:tcgplayer, tcg_price] : [:card_kingdom, ck_price]
      elsif tcg_price
        [:tcgplayer, tcg_price]
      elsif ck_price
        [:card_kingdom, ck_price]
      end

    if winner
      source, price = winner
      @card.update_columns(price: price, price_source: source.to_s)
      return { source: source.to_s, price: price }
    end

    scryfall_price = extract_scryfall_price(scryfall_data)
    if scryfall_price
      @card.update_columns(price: scryfall_price, price_source: "scryfall", price_reviewed: false)
      return { source: "scryfall", price: scryfall_price }
    end

    { source: nil }
  end

  def lookup_ck_by_scryfall_id(scryfall_id)
    return nil if scryfall_id.blank?
    is_foil = @card.foil.present?
    condition = @card.condition.presence || "NM"
    price = CardKingdomPriceService.pricelist[[scryfall_id, is_foil, condition]]
    price && price > 0 ? price : nil
  end

  def lookup_ck_by_name(scryfall_data)
    name = scryfall_data["name"]&.downcase&.strip
    edition_name = scryfall_data["set_name"]&.downcase&.strip
    return nil if name.blank? || edition_name.blank?

    is_foil = @card.foil.present?
    condition = @card.condition.presence || "NM"
    collector = CardKingdomPriceService.normalize_collector(@card.collector_number)
    ck_by_name = CardKingdomPriceService.pricelist_by_name

    # DFC/split cards: CK indexes under the front face name only.
    name_variants = [name]
    name_variants << name.split(" // ").first if name.include?(" // ")

    name_variants.each do |n|
      price = ck_by_name[[n, edition_name, collector, is_foil, condition]]
      return price if price && price > 0

      if @card.language.to_s.casecmp?("japanese")
        price = ck_by_name[[n, "#{edition_name} jpn", collector, is_foil, condition]]
        return price if price && price > 0
      end

      price = ck_by_name[[n, "promotional", collector, is_foil, condition]]
      return price if price && price > 0
    end

    nil
  end

  def extract_scryfall_price(scryfall_data)
    prices = scryfall_data["prices"] || {}
    price = @card.foil.present? ? prices["usd_foil"]&.to_f : prices["usd"]&.to_f
    price && price > 0 ? price : nil
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
