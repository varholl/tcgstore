class CardListParser
  ParsedLine = Struct.new(:name, :variant, :collector_number, :foil, :qty, :price, keyword_init: true)

  def self.parse_line(line)
    line = line.strip
    return nil if line.blank?

    # Strip leading X (may be attached: XCathars', X2, X 2)
    line = line.sub(/\AX\s*/, "")

    # Extract quantity at the beginning (e.g. "2 Arid Mesa ...")
    qty = 1
    if line.match?(/\A(\d+)\s+[A-Z]/i)
      m = line.match(/\A(\d+)\s+/)
      qty = m[1].to_i
      line = line[m[0].length..]
    end

    # Remove tabs, normalize whitespace
    line = line.gsub(/\t+/, " ").gsub(/\s+/, " ").strip

    # Extract collector number: #number possibly followed by p/s (promo/prerelease, part of
    # the collector number) and/or F/★ (foil indicator, not part of collector number).
    # Also handles F prefix: #F123 means foil collector number 123.
    collector_number = nil
    foil = false
    if line =~ /#([A-Za-z]*-?\d+[PpSs]?)([\u2605Ff]*)(\s|$)/
      full_match = Regexp.last_match
      raw_num = full_match[1]
      suffix = full_match[2]
      # Handle F/f prefix as foil indicator: #F123 -> collector_number=123, foil=true
      if raw_num =~ /\A[Ff](\d+[PpSs]?)\z/
        foil = true
        collector_number = $1
      else
        collector_number = raw_num
      end
      foil = true if suffix =~ /[Ff\u2605]/
      line = line.sub(/##{Regexp.escape(raw_num)}#{Regexp.escape(suffix)}/, " ")
    end

    # Extract variant info in parentheses
    variants = []
    line = line.gsub(/\([^)]*\)?\s*/) do |match|
      # Handle unclosed parens like "(Borderless"
      variant_text = match.gsub(/[()]/, "").strip
      variants << variant_text unless variant_text.empty?
      " "
    end
    variant = variants.any? ? variants.join(", ") : nil

    # Remove NM markers (may be attached to price: "NM13")
    line = line.gsub(/\bNM\s*/i, " ")

    # Remove trailing "cada" / "cads"
    line = line.gsub(/\b(?:cada|cads)\b/i, " ")

    # Remove stray "f" (foil indicator not attached to collector number)
    if line =~ /\bf\b/i
      foil = true
      line = line.gsub(/\bf\b/i, " ")
    end

    # Normalize whitespace again
    line = line.gsub(/\s+/, " ").strip

    # Extract price: last number on the line (may use comma decimal)
    price = nil
    if line =~ /(\d+(?:[,\.]\d+)?)\s*$/
      price_str = Regexp.last_match(1).tr(",", ".")
      price = BigDecimal(price_str)
      line = line.sub(/\s*\d+(?:[,\.]\d+)?\s*$/, "").strip
    end

    return nil unless price

    # Remove trailing special chars and quotes
    name = line.gsub(/["\s]+$/, "").strip

    # Skip garbled lines
    return nil if name.length < 2
    return nil if name =~ /\A[\d\s,]+\z/

    ParsedLine.new(
      name: name,
      variant: variant,
      collector_number: collector_number,
      foil: foil,
      qty: qty,
      price: price
    )
  end

  def self.match_card(parsed)
    clean_name = parsed.name.gsub(/\s*\(.*?\)\s*/, " ").gsub(/\s+/, " ").strip
    matches = Card.where("LOWER(name) = ?", clean_name.downcase)

    # Narrow by collector number if present
    if parsed.collector_number.present?
      narrowed = matches.where(collector_number: parsed.collector_number)
      matches = narrowed if narrowed.exists?
    end

    # Narrow by foil — strict: if F is specified, only match foil cards
    if parsed.foil
      matches = matches.where.not(foil: [nil, ""])
    elsif parsed.collector_number.present? && matches.count > 1
      # No foil flag: prefer non-foil version
      narrowed = matches.where(foil: [nil, ""])
      matches = narrowed if narrowed.exists?
    end

    if matches.count == 0
      { card: nil, status: :not_found }
    else
      { card: matches.first, status: :exact }
    end
  end

  def self.parse_and_match(text)
    lines = text.lines.map(&:strip)
    matched = []
    unmatched = []

    lines.each_with_index do |raw_line, idx|
      line_number = idx + 1
      next if raw_line.blank?

      parsed = parse_line(raw_line)

      unless parsed
        unmatched << { raw_line: raw_line, line_number: line_number, reason: :parse_error }
        next
      end

      result = match_card(parsed)

      if result[:card]
        matched << { card: result[:card], qty: parsed.qty, price: parsed.price, line: raw_line }
      else
        unmatched << { raw_line: raw_line, line_number: line_number, reason: :not_found }
      end
    end

    { matched: matched, unmatched: unmatched }
  end
end
