class CardKingdomPriceService
  API_URL = "https://api.cardkingdom.com/api/v2/pricelist"
  CACHE_KEY = "card_kingdom_pricelist"
  CACHE_TTL = 1.hour

  # Returns a hash keyed by [scryfall_id, is_foil] => price_retail
  def self.pricelist
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_pricelist }
  end

  def self.lookup(scryfall_id, foil: false)
    pricelist[[scryfall_id, foil]]
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
      price = entry['price_retail'].to_f
      lookup[[sid, is_foil]] = price if price > 0
    end
    lookup
  end

  private_class_method :fetch_pricelist
end
