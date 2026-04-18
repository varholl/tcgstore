class CardPriceRefreshService
  SCRYFALL_COLLECTION_URL = "https://api.scryfall.com/cards/collection"
  SCRYFALL_BATCH_SIZE = 75
  SCRYFALL_DELAY = 0.1 # 100ms between requests per Scryfall guidelines

  def call
    scryfall_ids_fetched = backfill_scryfall_ids
    prices_updated, prices_not_found = update_prices

    {
      scryfall_ids_fetched: scryfall_ids_fetched,
      prices_updated: prices_updated,
      prices_not_found: prices_not_found
    }
  end

  private

  # Refresh scryfall_ids for ALL cards (not just missing ones) because
  # Scryfall can change IDs over time, causing CK price lookups to fail.
  def backfill_scryfall_ids
    count = 0
    batch = []

    Card.where.not(edition: [nil, ""]).where.not(collector_number: [nil, ""]).find_each do |card|
      batch << card
      next if batch.size < SCRYFALL_BATCH_SIZE

      count += process_scryfall_id_batch(batch)
      batch = []
      sleep(SCRYFALL_DELAY)
    end

    count += process_scryfall_id_batch(batch) if batch.any?
    count
  end

  def process_scryfall_id_batch(batch)
    identifiers = batch.map { |c| { set: c.edition, collector_number: c.collector_number } }
    results = fetch_scryfall_collection(identifiers)
    count = 0

    results.each do |result|
      set_code = result["set"]
      collector_number = result["collector_number"]
      scryfall_id = result["id"]

      matching = batch.select { |c| c.edition == set_code && c.collector_number == collector_number }
      matching.each do |card|
        if card.scryfall_id != scryfall_id
          card.update_column(:scryfall_id, scryfall_id)
          count += 1
        end
      end
    end

    count
  end

  def fetch_scryfall_collection(identifiers)
    uri = URI(SCRYFALL_COLLECTION_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = { identifiers: identifiers }.to_json
    response = http.request(request)

    return [] unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("data", [])
  end

  def update_prices
    ck_prices = CardKingdomPriceService.pricelist
    updated = 0
    not_found = 0

    # Guard against an empty CK response (rate limit, outage, etc.) — without this,
    # every CK-sourced card would get nilified and the fallback queue would explode.
    if ck_prices.empty?
      Rails.logger.warn("CardPriceRefreshService: CK pricelist empty, skipping update_prices to avoid mass nilification.")
      return [updated, not_found]
    end

    Card.where.not(scryfall_id: [nil, ""]).find_each do |card|
      # New-set cards: skip CK so the fallback job can prefer TCGPlayer (Scryfall USD).
      if card.from_new_set?
        card.update_column(:price_source, nil)
        not_found += 1
        next
      end

      is_foil = card.foil.present?
      condition = card.condition.presence || "NM"
      ck_price = ck_prices[[card.scryfall_id, is_foil, condition]]

      if ck_price
        card.update_columns(price: ck_price, price_source: "card_kingdom")
        updated += 1
      elsif card.price_source == "card_kingdom"
        # CK used to have this card and no longer does — fall back to other sources.
        # For non-CK-sourced cards (Scryfall/TCGPlayer/manual), keep the existing price+source
        # to avoid bloating the fallback queue with cards that don't need reprocessing.
        card.update_column(:price_source, nil)
        not_found += 1
      end
    end

    # Clear pricelist from cache and memory after use
    Rails.cache.delete(CardKingdomPriceService::CACHE_KEY)
    ck_prices = nil

    [updated, not_found]
  end

end
