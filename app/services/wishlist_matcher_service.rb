class WishlistMatcherService
  WishlistEntry = Struct.new(:name, :qty, keyword_init: true)

  def self.parse(text)
    entries = []
    text.each_line do |line|
      line = line.strip
      next if line.blank?
      next if line.start_with?("//") || line.start_with?("#")

      # Skip section headers like "SIDEBOARD:", "Sideboard", "Maybeboard", etc.
      next if line.match?(/\A[A-Za-z]+:\s*\z/) || line.match?(/\A(Sideboard|Mainboard|Maybeboard|Commanders?|Companions?)\s*\z/i)

      qty = 1
      if line.match?(/\A(\d+)[xX]?\s+/)
        m = line.match(/\A(\d+)[xX]?\s+/)
        qty = m[1].to_i
        line = line[m[0].length..]
      end

      # Remove set code and collector number: (SET) 123
      name = line.sub(/\s*\([^)]+\)\s*\d*\s*$/, "").strip
      # Remove trailing collector number if still present
      name = name.sub(/\s+\d+\s*$/, "").strip
      # Remove trailing *F* or foil markers
      name = name.sub(/\s*\*F\*\s*$/, "").strip

      next if name.length < 2

      entries << WishlistEntry.new(name: name, qty: qty)
    end

    # Deduplicate by name, summing quantities
    entries.group_by { |e| e.name.downcase }.map do |_key, group|
      WishlistEntry.new(name: group.first.name, qty: group.sum(&:qty))
    end
  end

  def self.find_matches(entries)
    results = []

    entries.each do |entry|
      cards = Card.where("quantity > 0").where("LOWER(name) = ?", entry.name.downcase).to_a

      if cards.any?
        reserved = ReservationItem
          .joins(:reservation)
          .where(reservations: { status: %w[pending prepared paid shipped] }, card_id: cards.map(&:id))
          .group(:card_id)
          .sum(:quantity)

        # Group by card identity (across sellers) and aggregate
        groups = cards.group_by(&:card_identity)
        available_cards = []
        available_quantities = {}

        groups.each do |_identity, group|
          total_qty = group.sum(&:quantity)
          total_reserved = group.sum { |c| reserved[c.id] || 0 }
          available = total_qty - total_reserved
          next if available <= 0

          representative = group.min_by { |c| c.last_stocked_at || Time.at(0) }
          available_cards << representative
          available_quantities[representative.id] = available
        end
      else
        available_cards = []
        available_quantities = {}
      end

      results << {
        name: entry.name,
        qty: entry.qty,
        cards: available_cards,
        available_quantities: available_quantities
      }
    end

    results
  end

  def self.call(text)
    entries = parse(text)
    find_matches(entries)
  end
end
