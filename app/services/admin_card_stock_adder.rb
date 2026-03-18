class AdminCardStockAdder
  attr_reader :card, :result

  def initialize(params)
    @params = params
  end

  def call
    existing = find_existing

    if existing
      existing.update(scryfall_id: @params[:scryfall_id]) if existing.scryfall_id.blank?
      existing.increment!(:quantity, @params[:quantity].to_i)
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
        quantity: @params[:quantity].to_i,
        price: @params[:price]
      )

      if @card.save
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
    scope = scope.where(foil_condition)

    # Try by scryfall_id first
    if @params[:scryfall_id].present?
      found = scope.find_by(scryfall_id: @params[:scryfall_id])
      return found if found
    end

    # Fall back to edition (set code) + collector number
    scope.find_by(edition: @params[:set_code], collector_number: @params[:collector_number])
  end

  def foil_condition
    if @params[:foil].present?
      { foil: @params[:foil] }
    else
      ["foil IS NULL OR foil = ''"]
    end
  end
end
