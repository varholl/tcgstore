class AdminCardStockAdder
  attr_reader :card, :result

  def initialize(params)
    @params = params
  end

  def call
    existing = find_existing

    qty = @params[:quantity].to_i

    if existing
      existing.update(scryfall_id: @params[:scryfall_id]) if existing.scryfall_id.blank?
      backfill_metadata(existing)
      now = Time.current
      existing.increment!(:quantity, qty)
      existing.update_column(:last_stocked_at, now)
      existing.stock_entries.create!(quantity: qty, added_at: now)
      @card = existing
      @result = :incremented
    else
      @card = Card.new(
        name: @params[:name],
        edition: @params[:set_code],
        edition_name: @params[:set_name],
        collector_number: @params[:collector_number],
        scryfall_id: @params[:scryfall_id],
        condition: @params[:condition],
        language: @params[:language],
        foil: @params[:foil],
        foil_type: @params[:foil].present? ? @params[:foil_type] : nil,
        quantity: qty,
        price: @params[:price],
        seller_id: @params[:seller_id],
        colors: @params[:colors],
        mana_cost: @params[:mana_cost],
        cmc: @params[:cmc],
        card_type: @params[:card_type],
        card_subtype: @params[:card_subtype],
        rarity: @params[:rarity],
        release_date: @params[:release_date]
      )

      if @card.save
        @card.stock_entries.create!(quantity: qty, added_at: Time.current)
        # Try to fetch a Card Kingdom price (falls back to Scryfall) instead of
        # whatever the form prefilled (TCGplayer-derived).
        SingleCardPriceService.new(@card).call
        @result = :added
      else
        @result = false
      end
    end

    @result
  end

  private

  def find_existing
    scope = Card.where(condition: @params[:condition], language: @params[:language])
    scope = scope.where(seller_id: @params[:seller_id]) if @params[:seller_id].present?
    scope = scope.where(foil_condition)

    # Try by scryfall_id first
    if @params[:scryfall_id].present?
      found = scope.find_by(scryfall_id: @params[:scryfall_id])
      return found if found
    end

    # Fall back to edition (set code) + collector number
    scope.find_by(edition: @params[:set_code], collector_number: @params[:collector_number])
  end

  def backfill_metadata(card)
    metadata_fields = %i[colors mana_cost cmc card_type card_subtype rarity]
    updates = metadata_fields.each_with_object({}) do |field, h|
      h[field] = @params[field] if @params[field].present? && card.send(field).blank?
    end
    card.update_columns(updates) if updates.any?
  end

  def foil_condition
    if @params[:foil].present?
      { foil: @params[:foil] }
    else
      ["foil IS NULL OR foil = ''"]
    end
  end
end
