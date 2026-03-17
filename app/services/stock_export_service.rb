require "csv"

class StockExportService
  CONDITION_MAPPING = {
    "NM" => "Near Mint",
    "LP" => "Good (Lightly Played)",
    "MP" => "Played",
    "HP" => "Heavily Played",
    "DMG" => "Damaged"
  }.freeze

  HEADERS = [
    "Count", "Tradelist Count", "Name", "Edition", "Condition", "Language",
    "Foil", "Tags", "Last Modified", "Collector Number", "Alter", "Proxy", "Purchase Price"
  ].freeze

  def call
    cards = Card.where("quantity > 0").order(:name, :edition, :collector_number)

    CSV.generate(headers: true) do |csv|
      csv << HEADERS

      cards.find_each do |card|
        csv << [
          card.quantity,
          card.quantity,
          card.name,
          card.edition,
          CONDITION_MAPPING[card.condition] || card.condition,
          card.language,
          export_foil(card.foil),
          "",
          card.updated_at&.strftime("%Y-%m-%d %H:%M:%S.%6N"),
          card.collector_number,
          "False",
          "False",
          card.purchase_price.present? ? format("%.2f", card.purchase_price) : ""
        ]
      end
    end
  end

  private

  def export_foil(foil)
    case foil
    when "Yes" then "foil"
    when "Yes (Etched)" then "etched"
    else ""
    end
  end
end
