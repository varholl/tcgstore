require 'csv'

namespace :cards do
  desc "Import cards from varholl_garage_sale.csv"
  task import: :environment do
    file_path = Rails.root.join('varholl_garage_sale.csv')

    unless File.exist?(file_path)
      puts "CSV file not found at #{file_path}"
      exit 1
    end

    count = 0
    CSV.foreach(file_path, headers: true, encoding: 'bom|utf-8') do |row|
      foil_value = case row['Foil'].to_s.strip.downcase
                   when 'foil' then 'Yes'
                   when 'etched' then 'Yes (Etched)'
                   else ''
                   end

      purchase_price = row['Purchase Price'].to_s.strip
      purchase_price = purchase_price.empty? ? nil : purchase_price.to_f

      condition_mapping = {
        "Near Mint" => "NM",
        "Good (Lightly Played)" => "LP",
        "Played" => "MP",
        "Heavily Played" => "HP",
        "Damaged" => "DMG"
      }
      raw_condition = row['Condition'].to_s.strip
      normalized_condition = condition_mapping[raw_condition] || raw_condition

      Card.create!(
        name: row['Name'],
        edition: row['Edition'],
        condition: normalized_condition,
        language: row['Language'],
        foil: foil_value,
        quantity: row['Count'].to_i,
        collector_number: row['Collector Number'],
        purchase_price: purchase_price
      )

      count += 1
      print "\rImported #{count} cards..." if count % 100 == 0
    end

    puts "\nDone! Imported #{count} cards total."
  end

  desc "Fetch Scryfall IDs for cards missing them"
  task fetch_scryfall_ids: :environment do
    require 'net/http'
    require 'json'

    cards = Card.where(scryfall_id: [nil, ''])
    total = cards.count

    if total == 0
      puts "All cards already have Scryfall IDs."
      next
    end

    puts "Fetching Scryfall IDs for #{total} cards..."
    updated = 0
    errors = 0

    cards.find_each.with_index do |card, index|
      begin
        uri = URI("https://api.scryfall.com/cards/#{card.edition}/#{card.collector_number}")
        response = Net::HTTP.get_response(uri)

        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          card.update_column(:scryfall_id, data['id'])
          updated += 1
        else
          errors += 1
          puts "\nHTTP #{response.code} for #{card.name} (#{card.edition}/#{card.collector_number})"
        end
      rescue => e
        errors += 1
        puts "\nError for #{card.name} (#{card.edition}/#{card.collector_number}): #{e.message}"
      end

      print "\rProcessed #{index + 1}/#{total} (#{updated} updated, #{errors} errors)..."
      sleep 0.1 # Scryfall rate limit: 10 requests/second
    end

    puts "\nDone! Updated #{updated} Scryfall IDs. #{errors} errors."
  end

  desc "Fetch edition names from Scryfall sets API"
  task fetch_edition_names: :environment do
    require 'net/http'
    require 'json'

    puts "Fetching set names from Scryfall..."
    uri = URI("https://api.scryfall.com/sets")
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      puts "Failed to fetch sets: HTTP #{response.code}"
      exit 1
    end

    data = JSON.parse(response.body)
    set_names = {}
    data['data'].each { |s| set_names[s['code']] = s['name'] }
    puts "Loaded #{set_names.length} set names."

    editions = Card.distinct.pluck(:edition)
    updated = 0
    not_found = []

    editions.each do |code|
      name = set_names[code]
      if name
        Card.where(edition: code).update_all(edition_name: name)
        updated += 1
      else
        not_found << code
      end
    end

    puts "Done! Updated #{updated} editions."
    puts "Not found: #{not_found.join(', ')}" if not_found.any?
  end

  desc "Fetch prices from Card Kingdom API"
  task fetch_prices: :environment do
    require 'net/http'
    require 'json'

    missing = Card.where(scryfall_id: [nil, '']).count
    if missing > 0
      puts "Note: #{missing} cards are missing Scryfall IDs and will be skipped. Run `rails cards:fetch_scryfall_ids` to fetch them."
    end

    puts "Downloading Card Kingdom pricelist..."
    uri = URI("https://api.cardkingdom.com/api/v2/pricelist")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/json'
    request['User-Agent'] = 'Mozilla/5.0'
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      puts "Failed to fetch Card Kingdom pricelist: HTTP #{response.code}"
      exit 1
    end

    data = JSON.parse(response.body)
    ck_cards = data['data']
    puts "Loaded #{ck_cards.length} Card Kingdom entries."

    # Build lookup by [scryfall_id, is_foil]
    ck_lookup = {}
    ck_cards.each do |ck_card|
      sid = ck_card['scryfall_id']
      next if sid.nil? || sid.empty?
      is_foil = ck_card['is_foil'] == 'true'
      ck_lookup[[sid, is_foil]] = ck_card
    end

    puts "Matching prices..."
    cards = Card.where.not(scryfall_id: [nil, ''])
    total = cards.count
    updated = 0
    not_found = 0

    cards.find_each.with_index do |card, index|
      is_foil = card.foil.present?
      ck_entry = ck_lookup[[card.scryfall_id, is_foil]]

      if ck_entry
        price = ck_entry['price_retail'].to_f
        card.update_column(:price, price) if price > 0
        updated += 1
      else
        not_found += 1
      end

      print "\rProcessed #{index + 1}/#{total} (#{updated} priced, #{not_found} not found)..."
    end

    puts "\nDone! Updated #{updated} cards with Card Kingdom prices. #{not_found} not found in CK."
  end
end
