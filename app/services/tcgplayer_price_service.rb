class TcgplayerPriceService
  PRICEPOINTS_URL = "https://mpapi.tcgplayer.com/v2/product/%{id}/pricepoints"
  SEARCH_URL = "https://mp-search-api.tcgplayer.com/v1/search/request"
  TIMEOUT = 5
  SEARCH_CACHE_TTL = 30.days

  def self.lookup(tcgplayer_id, foil:)
    return nil if tcgplayer_id.blank?
    fetch_pricepoint(tcgplayer_id, foil: foil)
  end

  # Find a TCGPlayer product by searching name + set when Scryfall doesn't expose
  # tcgplayer_id (common for JP Alternate Art prints). Matches on collector number
  # and foil status, then fetches the pricepoint. Product IDs are cached to avoid
  # re-searching on every refresh.
  def self.lookup_by_search(name:, set_name:, collector_number:, foil:)
    product_id = find_product_id(name: name, set_name: set_name, collector_number: collector_number, foil: foil)
    return nil if product_id.nil?
    fetch_pricepoint(product_id, foil: foil)
  end

  def self.find_product_id(name:, set_name:, collector_number:, foil:)
    return nil if name.blank? || set_name.blank? || collector_number.blank?

    cache_key = ["tcgplayer_product_id", set_name.downcase, collector_number.to_s, foil ? "foil" : "normal"]
    cached = Rails.cache.read(cache_key)
    return cached if cached.is_a?(Integer)

    results = search_products(name: name, set_name: set_name)
    return nil if results.empty?

    matching = results.select { |r| r.dig("customAttributes", "number").to_s == collector_number.to_s }
    foil_matches    = matching.select { |r| r["productName"].to_s =~ /foil/i }
    nonfoil_matches = matching.reject { |r| r["productName"].to_s =~ /foil/i }

    chosen = foil ? foil_matches.first : nonfoil_matches.first
    product_id = chosen&.dig("productId")&.to_i
    Rails.cache.write(cache_key, product_id, expires_in: SEARCH_CACHE_TTL) if product_id
    product_id
  end

  def self.fetch_pricepoint(tcgplayer_id, foil:)
    uri = URI(PRICEPOINTS_URL % { id: tcgplayer_id })
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0'
    request['Accept'] = 'application/json'
    response = http.request(request)

    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    target = foil ? "Foil" : "Normal"
    entry = data.find { |e| e["printingType"] == target }
    return nil unless entry

    price = entry["marketPrice"] || entry["listedMedianPrice"]
    price && price.to_f > 0 ? price.to_f : nil
  rescue StandardError
    nil
  end

  def self.search_products(name:, set_name:)
    uri = URI("#{SEARCH_URL}?q=#{URI.encode_www_form_component(name)}&isList=true")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "User-Agent" => "Mozilla/5.0")
    request.body = {
      algorithm: "",
      from: 0,
      size: 20,
      filters: {
        term: { productLineName: ["magic"], setName: [set_name] },
        range: {},
        match: {}
      },
      context: { cart: {}, shippingCountry: "US" },
      settings: { useKeywordSearch: false }
    }.to_json

    response = http.request(request)
    return [] unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig("results", 0, "results") || []
  rescue StandardError
    []
  end

  private_class_method :fetch_pricepoint, :search_products
end
