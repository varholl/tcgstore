require "csv"

namespace :trade do
  desc "Evaluate a trade list against the DB. Usage: rake trade:evaluate[cartas_trade.txt]"
  task :evaluate, [:input_file] => :environment do |_t, args|
    input_file = args[:input_file] || "cartas_trade.txt"

    unless File.exist?(input_file)
      puts "ERROR: File '#{input_file}' not found."
      exit 1
    end

    output_file = "tmp/trade_evaluation.csv"
    FileUtils.mkdir_p("tmp")

    lines = File.readlines(input_file, encoding: "utf-8").map(&:strip)

    stats = { exact: 0, not_found: 0, parse_error: 0, total: 0 }

    CSV.open(output_file, "w") do |csv|
      csv << %w[
        line_number parsed_name variant_info collector_number qty
        their_price match_status card_id db_name db_edition
        db_collector_number db_foil db_price pct_offered
      ]

      lines.each_with_index do |raw_line, idx|
        line_number = idx + 1
        stats[:total] += 1

        parsed = CardListParser.parse_line(raw_line)

        unless parsed
          stats[:parse_error] += 1
          csv << [line_number, raw_line, nil, nil, nil, nil, "PARSE_ERROR",
                  nil, nil, nil, nil, nil, nil, nil]
          next
        end

        result = CardListParser.match_card(parsed)

        if result[:status] == :not_found
          stats[:not_found] += 1
          csv << [line_number, parsed.name, parsed.variant, parsed.collector_number,
                  parsed.qty, parsed.price, "NOT_FOUND",
                  nil, nil, nil, nil, nil, nil, nil]
        else
          stats[:exact] += 1
          card = result[:card]
          pct = card.price&.positive? ? (parsed.price / card.price * 100).round(1) : nil
          csv << [line_number, parsed.name, parsed.variant, parsed.collector_number,
                  parsed.qty, parsed.price, "EXACT",
                  card.id, card.name, card.edition_name, card.collector_number,
                  card.foil, card.price&.to_f, pct ? "#{pct}%" : nil]
        end
      end
    end

    puts "Trade evaluation complete!"
    puts "  Input:       #{input_file} (#{stats[:total]} lines)"
    puts "  Output:      #{output_file}"
    puts "  Exact:       #{stats[:exact]}"
    puts "  Not found:   #{stats[:not_found]}"
    puts "  Parse error: #{stats[:parse_error]}"
  end
end
