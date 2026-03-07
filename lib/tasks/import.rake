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

      Card.create!(
        name: row['Name'],
        edition: row['Edition'],
        condition: row['Condition'],
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

  desc "Fetch prices from Scryfall API"
  task fetch_prices: :environment do
    require 'net/http'
    require 'json'

    cards = Card.all
    total = cards.count
    updated = 0
    errors = 0

    puts "Fetching prices for #{total} cards from Scryfall..."

    cards.find_each.with_index do |card, index|
      begin
        uri = URI("https://api.scryfall.com/cards/#{card.edition}/#{card.collector_number}")
        response = Net::HTTP.get_response(uri)

        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          price = if card.foil.present?
                    data.dig('prices', 'usd_foil')
                  else
                    data.dig('prices', 'usd')
                  end

          if price
            card.update_column(:price, price.to_f)
            updated += 1
          end
        else
          errors += 1
        end
      rescue => e
        errors += 1
        puts "\nError for #{card.name} (#{card.edition}/#{card.collector_number}): #{e.message}"
      end

      print "\rProcessed #{index + 1}/#{total} (#{updated} priced, #{errors} errors)..."
      sleep 0.1 # Scryfall rate limit: 10 requests/second
    end

    puts "\nDone! Updated #{updated} cards with prices. #{errors} errors."
  end
end
