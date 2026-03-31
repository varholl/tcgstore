module ScryfallMetadataExtractor
  def self.extract(data)
    face = data["card_faces"]&.first

    colors    = data["colors"] || face&.dig("colors") || []
    mana_cost = data["mana_cost"] || face&.dig("mana_cost")
    type_line = face&.dig("type_line") || data["type_line"] || ""
    cmc       = data["cmc"]
    rarity    = data["rarity"]

    card_type, card_subtype = split_type_line(type_line)

    {
      colors: colors.join(","),
      mana_cost: mana_cost,
      cmc: cmc,
      card_type: card_type,
      card_subtype: card_subtype,
      rarity: rarity
    }
  end

  def self.split_type_line(type_line)
    parts = type_line.split(" \u2014 ", 2)
    [parts[0]&.strip, parts[1]&.strip]
  end
end
