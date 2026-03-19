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

  # Returns a hash keyed by [scryfall_id, is_foil, condition] => price.
  # When multiple CK entries share the same scryfall_id (base + variants),
  # non-variant entries are preferred. Variant cards with different Scryfall
  # IDs will fall through to the by-name pricelist which uses collector_number.
  def self.pricelist
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { fetch_pricelist }
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

    # Only keep scryfall_ids we actually have in the database to reduce memory
    known_scryfall_ids = Card.where.not(scryfall_id: [nil, ""]).distinct.pluck(:scryfall_id).to_set

    raw_body = response.body
    data = JSON.parse(raw_body)
    raw_body = nil # allow GC to reclaim the raw string

    lookup = {}
    data['data'].each do |entry|
      sid = entry['scryfall_id']
      next if sid.nil? || sid.empty?
      next unless known_scryfall_ids.include?(sid)

      variation = entry['variation'].to_s.strip
      is_foil = entry['is_foil'] == 'true'
      condition_values = entry['condition_values'] || {}

      CONDITION_MAP.each do |condition, ck_key|
        price = condition_values[ck_key]&.to_f
        next unless price && price > 0

        key = [sid, is_foil, condition]
        # When multiple entries share the same scryfall_id (base + variants),
        # prefer the non-variant entry. Variant entries are only stored when
        # no entry exists yet for the same key.
        if !lookup.key?(key) || variation.blank?
          lookup[key] = price
        end
      end
    end
    data = nil # allow GC to reclaim parsed JSON
    lookup
  end

  # Returns a hash keyed by [name_downcased, edition, collector_number, is_foil, condition] => price
  # Used as fallback when scryfall_id matching fails.
  # Includes collector_number (extracted from CK SKU) to distinguish base
  # printings from variants that share the same card name.
  CACHE_KEY_BY_NAME = "card_kingdom_pricelist_by_name"

  def self.pricelist_by_name
    Rails.cache.fetch(CACHE_KEY_BY_NAME, expires_in: CACHE_TTL) { fetch_pricelist_by_name }
  end

  def self.fetch_pricelist_by_name
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/json'
    request['User-Agent'] = 'Mozilla/5.0'
    response = http.request(request)

    return {} unless response.is_a?(Net::HTTPSuccess)

    raw_body = response.body
    data = JSON.parse(raw_body)
    raw_body = nil

    lookup = {}
    data['data'].each do |entry|
      name = entry['name']&.downcase&.strip
      next if name.nil? || name.empty?

      is_foil = entry['is_foil'] == 'true'
      # Normalize edition: strip " variants" suffix so variant entries
      # share the same edition key as base entries (matching Scryfall's set_name).
      edition = entry['edition']&.downcase&.strip&.sub(/ variants\z/, '')
      # Extract collector number from SKU (e.g. "LTR-0026" → "26", "SFLTR-0477" → "477")
      sku = entry['sku'].to_s
      sku_collector = normalize_collector(sku.split('-').last)
      condition_values = entry['condition_values'] || {}

      CONDITION_MAP.each do |condition, ck_key|
        price = condition_values[ck_key]&.to_f
        if price && price > 0 && edition.present? && sku_collector.present?
          lookup[[name, edition, sku_collector, is_foil, condition]] = price
        end
      end
    end
    data = nil
    lookup
  end

  # Normalize a collector number for matching: strip leading zeros, downcase,
  # and take only the part after the last dash (handles Scryfall's "The List"
  # format like "LRW-256" → "256", matching CK's SKU extraction).
  def self.normalize_collector(value)
    value.to_s.split('-').last.to_s.gsub(/\A0+/, '').downcase
  end

  private_class_method :fetch_pricelist, :fetch_pricelist_by_name
end
