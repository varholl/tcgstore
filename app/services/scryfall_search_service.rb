class ScryfallSearchService
  SCRYFALL_API = "https://api.scryfall.com"

  def initialize(query)
    @query = query
  end

  def call
    return [] if @query.blank?

    uri = URI("#{SCRYFALL_API}/cards/search")
    uri.query = URI.encode_www_form(q: @query, unique: "prints", order: "released")

    response = Net::HTTP.get_response(uri)
    return [] unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    return [] unless data["data"]

    data["data"].first(20).map do |card|
      {
        scryfall_id: card["id"],
        name: card["name"],
        set_name: card["set_name"],
        set_code: card["set"],
        collector_number: card["collector_number"],
        image_small: card.dig("image_uris", "small") || card.dig("card_faces", 0, "image_uris", "small"),
        prices_usd: card.dig("prices", "usd"),
        prices_usd_foil: card.dig("prices", "usd_foil"),
        finishes: card["finishes"] || [],
        promo_types: card["promo_types"] || []
      }.merge(ScryfallMetadataExtractor.extract(card))
    end
  end
end
