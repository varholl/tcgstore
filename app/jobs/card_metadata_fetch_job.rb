class CardMetadataFetchJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 75
  SCRYFALL_COLLECTION_URL = "https://api.scryfall.com/cards/collection"

  def perform
    require 'net/http'
    require 'json'

    cards = Card.where(card_type: [nil, '']).to_a
    return if cards.empty?

    cards.each_slice(BATCH_SIZE) do |batch|
      identifiers = batch.map { |c| { set: c.edition, collector_number: c.collector_number } }

      begin
        uri = URI(SCRYFALL_COLLECTION_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        request.body = { identifiers: identifiers }.to_json

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          scryfall_cards = data["data"] || []

          scryfall_cards.each do |sc|
            set_code = sc["set"]
            collector_number = sc["collector_number"]
            metadata = ScryfallMetadataExtractor.extract(sc)

            matching = batch.select { |c| c.edition == set_code && c.collector_number == collector_number }
            matching.each do |card|
              card.update_columns(metadata)
            end
          end
        else
          Rails.logger.warn("CardMetadataFetchJob: HTTP #{response.code} for batch of #{batch.size}")
        end
      rescue => e
        Rails.logger.warn("CardMetadataFetchJob: Error for batch: #{e.message}")
      end

      sleep 0.1
    end
  end
end
