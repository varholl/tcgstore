require "csv"

class StockReconciliationService
  CONDITION_MAPPING = {
    "Near Mint" => "NM",
    "Good (Lightly Played)" => "LP",
    "Played" => "MP",
    "Heavily Played" => "HP",
    "Damaged" => "DMG"
  }.freeze

  Result = Struct.new(:success, :cards_created, :cards_updated, :cards_zeroed,
                      :cards_unchanged, :reservation_conflicts, :errors, keyword_init: true)

  def initialize(csv_file, mode:)
    @csv_file = csv_file
    @mode = mode.to_sym
  end

  def call
    csv_rows = parse_csv
    return error_result(csv_rows) if csv_rows.is_a?(Array) && csv_rows.first.is_a?(String)

    reconcile(csv_rows)
  rescue CSV::MalformedCSVError => e
    Result.new(success: false, errors: ["Malformed CSV: #{e.message}"])
  end

  private

  def parse_csv
    rows = {}
    errors = []

    content = @csv_file.read.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    content = content.sub(/\A\xEF\xBB\xBF/, "") # strip BOM

    CSV.parse(content, headers: true) do |row|
      edition = row["Edition"].to_s.strip.downcase
      collector_number = row["Collector Number"].to_s.strip
      condition = normalize_condition(row["Condition"].to_s.strip)
      language = row["Language"].to_s.strip
      foil = normalize_foil(row["Foil"].to_s.strip)

      if edition.blank? || collector_number.blank?
        errors << "Skipped row: missing edition or collector number for '#{row['Name']}'"
        next
      end

      key = [edition, collector_number, condition, language, foil]
      count = row["Count"].to_i
      purchase_price = row["Purchase Price"].to_s.strip
      purchase_price = purchase_price.present? ? purchase_price.to_f : nil

      if rows[key]
        rows[key][:quantity] += count
      else
        rows[key] = {
          name: row["Name"].to_s.strip,
          edition: edition,
          collector_number: collector_number,
          condition: condition,
          language: language,
          foil: foil,
          quantity: count,
          purchase_price: purchase_price
        }
      end
    end

    return errors if errors.any? && rows.empty?
    rows
  end

  def reconcile(csv_rows)
    existing_cards = Card.all.index_by { |c| card_key(c) }
    edition_names = Card.where.not(edition_name: [nil, ""]).distinct.pluck(:edition, :edition_name).to_h
    scryfall_ids = Card.where.not(scryfall_id: [nil, ""]).pluck(:edition, :collector_number, :scryfall_id)
                       .each_with_object({}) { |(ed, cn, sid), h| h[[ed, cn]] = sid }

    created = 0
    updated = 0
    zeroed = 0
    unchanged = 0
    conflicts = []
    matched_keys = Set.new

    ActiveRecord::Base.transaction do
      csv_rows.each do |key, row_data|
        matched_keys << key
        card = existing_cards[key]

        if card
          new_quantity = @mode == :full ? row_data[:quantity] : card.quantity + row_data[:quantity]

          if card.quantity != new_quantity || card.purchase_price != row_data[:purchase_price]
            card.update_columns(quantity: new_quantity, purchase_price: row_data[:purchase_price])
            updated += 1
          else
            unchanged += 1
          end
        else
          Card.create!(
            name: row_data[:name],
            edition: row_data[:edition],
            edition_name: edition_names[row_data[:edition]],
            collector_number: row_data[:collector_number],
            condition: row_data[:condition],
            language: row_data[:language],
            foil: row_data[:foil],
            quantity: row_data[:quantity],
            purchase_price: row_data[:purchase_price],
            scryfall_id: scryfall_ids[[row_data[:edition], row_data[:collector_number]]]
          )
          created += 1
        end
      end

      if @mode == :full
        cards_to_zero = existing_cards.reject { |key, _| matched_keys.include?(key) }
        cards_to_zero_with_stock = cards_to_zero.values.select { |c| c.quantity > 0 }

        if cards_to_zero_with_stock.any?
          ids_to_zero = cards_to_zero_with_stock.map(&:id)

          conflict_items = ReservationItem.joins(:reservation)
            .where(card_id: ids_to_zero, reservations: { status: %w[pending paid] })
            .includes(:card, :reservation)

          conflict_items.group_by(&:card_id).each do |card_id, items|
            card = cards_to_zero_with_stock.find { |c| c.id == card_id }
            reservation_ids = items.map(&:reservation_id).uniq
            conflicts << {
              card: card,
              reservation_ids: reservation_ids,
              reserved_quantity: items.sum(&:quantity)
            }
          end

          Card.where(id: ids_to_zero).update_all(quantity: 0)
          zeroed = cards_to_zero_with_stock.size
        end
      end
    end

    Result.new(
      success: true,
      cards_created: created,
      cards_updated: updated,
      cards_zeroed: zeroed,
      cards_unchanged: unchanged,
      reservation_conflicts: conflicts,
      errors: []
    )
  end

  def card_key(card)
    [card.edition.to_s.downcase, card.collector_number.to_s.strip, card.condition, card.language, card.foil]
  end

  def normalize_condition(raw)
    CONDITION_MAPPING[raw] || raw
  end

  def normalize_foil(raw)
    case raw.downcase
    when "foil" then "Yes"
    when "etched" then "Yes (Etched)"
    else ""
    end
  end

  def error_result(errors)
    Result.new(success: false, errors: errors)
  end
end
