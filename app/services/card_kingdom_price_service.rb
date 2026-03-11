class CardKingdomPriceService
  API_URL = "https://api.cardkingdom.com/api/v2/pricelist"
  CACHE_KEY = "card_kingdom_pricelist"
  CACHE_TTL = 1.hour

  # Maps our conditions to Card Kingdom condition_values keys
  CONDITION_MAP = {
    "NM"  => "nm_price",
    "LP"  => "ex_price",
    "MP"  => "vg_price",
    "HP"  => "g_price",
    "DMG" => "g_price"
  }.freeze

  # Returns a hash keyed by [scryfall_id, is_foil, condition] => price
  def self.pricelist
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_pricelist }
  end

  def self.lookup(scryfall_id, foil: false, condition: "NM")
    pricelist[[scryfall_id, foil, condition]]
  end

  # Look up prices for a set of scryfall_ids. Returns all condition variants.
  def self.lookup_batch(scryfall_ids)
    target_ids = scryfall_ids.to_set
    results = {}
    pricelist.each do |key, price|
      results[key] = price if target_ids.include?(key[0])
    end
    results
  end

  def self.fetch_pricelist
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/json'
    request['User-Agent'] = 'Mozilla/5.0'
    response = http.request(request)

    return {} unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    lookup = {}
    data['data'].each do |entry|
      sid = entry['scryfall_id']
      next if sid.nil? || sid.empty?
      is_foil = entry['is_foil'] == 'true'
      condition_values = entry['condition_values'] || {}

      CONDITION_MAP.each do |condition, ck_key|
        price = condition_values[ck_key]&.to_f
        # Fall back to price_retail if condition_values is missing
        price = entry['price_retail'].to_f if price.nil? || price <= 0
        lookup[[sid, is_foil, condition]] = price if price > 0
      end
    end
    lookup
  end

  private_class_method :fetch_pricelist
end
