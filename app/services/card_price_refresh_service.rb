class CardPriceRefreshService
  SCRYFALL_COLLECTION_URL = "https://api.scryfall.com/cards/collection"
  SCRYFALL_BATCH_SIZE = 75

  def call
    scryfall_ids_fetched = backfill_scryfall_ids
    prices_updated, prices_not_found = update_prices

    { scryfall_ids_fetched: scryfall_ids_fetched, prices_updated: prices_updated, prices_not_found: prices_not_found }
  end

  private

  def backfill_scryfall_ids
    cards = Card.where(scryfall_id: [nil, ""]).where.not(edition: [nil, ""]).where.not(collector_number: [nil, ""])
    return 0 if cards.empty?

    count = 0
    cards.each_slice(SCRYFALL_BATCH_SIZE) do |batch|
      identifiers = batch.map { |c| { set: c.edition, collector_number: c.collector_number } }
      results = fetch_scryfall_collection(identifiers)

      results.each do |result|
        set_code = result["set"]
        collector_number = result["collector_number"]
        scryfall_id = result["id"]

        matching = batch.select { |c| c.edition == set_code && c.collector_number == collector_number }
        matching.each do |card|
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

    Card.where.not(scryfall_id: [nil, ""]).find_each do |card|
      is_foil = card.foil.present?
      ck_price = ck_prices[[card.scryfall_id, is_foil]]

      if ck_price
        card.update_column(:price, ck_price)
        updated += 1
      else
        not_found += 1
      end
    end

    [updated, not_found]
  end
end
