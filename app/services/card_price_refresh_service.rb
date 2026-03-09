class CardPriceRefreshService
  SCRYFALL_COLLECTION_URL = "https://api.scryfall.com/cards/collection"
  SCRYFALL_BATCH_SIZE = 75
  SCRYFALL_DELAY = 0.1 # 100ms between requests per Scryfall guidelines

  def call
    scryfall_ids_fetched = backfill_scryfall_ids
    prices_updated, prices_not_found = update_prices
    scryfall_prices_updated = backfill_prices_from_scryfall

    {
      scryfall_ids_fetched: scryfall_ids_fetched,
      prices_updated: prices_updated + scryfall_prices_updated,
      prices_not_found: prices_not_found - scryfall_prices_updated
    }
  end

  private

  # Refresh scryfall_ids for ALL cards (not just missing ones) because
  # Scryfall can change IDs over time, causing CK price lookups to fail.
  def backfill_scryfall_ids
    cards = Card.where.not(edition: [nil, ""]).where.not(collector_number: [nil, ""])
    return 0 if cards.empty?

    count = 0
    cards.each_slice(SCRYFALL_BATCH_SIZE).with_index do |batch, idx|
      sleep(SCRYFALL_DELAY) if idx > 0

      identifiers = batch.map { |c| { set: c.edition, collector_number: c.collector_number } }
      results = fetch_scryfall_collection(identifiers)

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

    Card.where.not(scryfall_id: [nil, ""]).find_each do |card|
      is_foil = card.foil.present?
      ck_price = ck_prices[[card.scryfall_id, is_foil]]

      if ck_price
        card.update_columns(price: ck_price, price_source: "card_kingdom")
        updated += 1
      else
        not_found += 1
      end
    end

    [updated, not_found]
  end

  # Fallback: fetch prices from Scryfall for cards that still have no price
  def backfill_prices_from_scryfall
    cards = Card.where(price: nil).where.not(scryfall_id: [nil, ""]).to_a
    return 0 if cards.empty?

    count = 0
    cards.each_slice(SCRYFALL_BATCH_SIZE).with_index do |batch, idx|
      sleep(SCRYFALL_DELAY) if idx > 0

      identifiers = batch.map { |c| { id: c.scryfall_id } }
      results = fetch_scryfall_collection(identifiers)

      scryfall_prices = {}
      results.each do |result|
        sid = result["id"]
        prices = result["prices"] || {}
        scryfall_prices[sid] = {
          usd: prices["usd"]&.to_f,
          usd_foil: prices["usd_foil"]&.to_f
        }
      end

      batch.each do |card|
        sp = scryfall_prices[card.scryfall_id]
        next unless sp

        price = card.foil.present? ? sp[:usd_foil] : sp[:usd]
        if price && price > 0
          card.update_columns(price: price, price_source: "scryfall")
          count += 1
        end
      end
    end

    count
  end
end
