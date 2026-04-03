require "test_helper"
require "stringio"

class StockReconciliationServiceTest < ActiveSupport::TestCase
  setup do
    @seller = sellers(:default_seller)
  end

  test "creates new cards from manabox CSV" do
    csv = <<~CSV
      Name,Set code,Set name,Collector number,Foil,Rarity,Quantity,ManaBox ID,Scryfall ID,Purchase price,Misprint,Altered,Condition,Language,Purchase price currency
      Sol Ring,c21,Commander 2021,266,normal,uncommon,2,123,,0.00,false,false,near_mint,en,USD
    CSV

    service = StockReconciliationService.new(
      uploaded_file(csv), mode: :partial, format: :manabox, seller: @seller
    )
    result = service.call

    assert result.success
    assert_equal 1, result.cards_created
    card = Card.find_by(name: "Sol Ring", edition: "c21", seller: @seller)
    assert_equal 2, card.quantity
    assert_equal "NM", card.condition
    assert_equal "English", card.language
  end

  test "increments existing card in partial mode" do
    bolt = cards(:lightning_bolt)
    original_qty = bolt.quantity

    csv = <<~CSV
      Count,Tradelist Count,Name,Edition,Condition,Language,Foil,Tags,Last Modified,Collector Number,Alter,Proxy,Purchase Price
      2,,Lightning Bolt,lea,Near Mint,English,,,2026-01-01,161,,,
    CSV

    service = StockReconciliationService.new(
      uploaded_file(csv), mode: :partial, format: :moxfield, seller: @seller
    )
    result = service.call

    assert result.success
    assert_equal 1, result.cards_updated

    bolt.reload
    assert_equal original_qty + 2, bolt.quantity
  end

  test "full mode zeroes cards not in CSV" do
    csv = <<~CSV
      Count,Tradelist Count,Name,Edition,Condition,Language,Foil,Tags,Last Modified,Collector Number,Alter,Proxy,Purchase Price
      2,,Counterspell,ice,Good (Lightly Played),English,,,2026-01-01,64,,,
    CSV

    service = StockReconciliationService.new(
      uploaded_file(csv), mode: :full, format: :moxfield, seller: @seller
    )
    result = service.call

    assert result.success
    # lightning_bolt (same seller, not in CSV) should be zeroed
    assert result.cards_zeroed > 0
  end

  test "applies release_date to new cards" do
    release = 30.days.from_now.to_date

    csv = <<~CSV
      Name,Set code,Set name,Collector number,Foil,Rarity,Quantity,ManaBox ID,Scryfall ID,Purchase price,Misprint,Altered,Condition,Language,Purchase price currency
      New Preorder Card,fdn,Foundations,99,normal,rare,3,456,,0.00,false,false,near_mint,en,USD
    CSV

    service = StockReconciliationService.new(
      uploaded_file(csv), mode: :partial, format: :manabox, seller: @seller, release_date: release.to_s
    )
    result = service.call

    assert result.success
    card = Card.find_by(name: "New Preorder Card", edition: "fdn", seller: @seller)
    assert_equal release, card.release_date
    assert card.preorder?
  end

  test "applies release_date to existing cards" do
    bolt = cards(:lightning_bolt)
    assert_nil bolt.release_date

    release = 30.days.from_now.to_date

    csv = <<~CSV
      Count,Tradelist Count,Name,Edition,Condition,Language,Foil,Tags,Last Modified,Collector Number,Alter,Proxy,Purchase Price
      1,,Lightning Bolt,lea,Near Mint,English,,,2026-01-01,161,,,
    CSV

    service = StockReconciliationService.new(
      uploaded_file(csv), mode: :partial, format: :moxfield, seller: @seller, release_date: release.to_s
    )
    result = service.call

    assert result.success
    bolt.reload
    assert_equal release, bolt.release_date
  end

  test "does not set release_date when not provided" do
    csv = <<~CSV
      Name,Set code,Set name,Collector number,Foil,Rarity,Quantity,ManaBox ID,Scryfall ID,Purchase price,Misprint,Altered,Condition,Language,Purchase price currency
      Plain Card,tst,Test Set,1,normal,common,1,789,,0.00,false,false,near_mint,en,USD
    CSV

    service = StockReconciliationService.new(
      uploaded_file(csv), mode: :partial, format: :manabox, seller: @seller
    )
    result = service.call

    assert result.success
    card = Card.find_by(name: "Plain Card", edition: "tst", seller: @seller)
    assert_nil card.release_date
  end

  test "returns error for malformed CSV" do
    service = StockReconciliationService.new(
      uploaded_file("not,a,valid\ncsv\"broken"), mode: :partial, format: :manabox, seller: @seller
    )
    result = service.call

    assert_not result.success
  end

  test "reports reservation conflicts when zeroing cards" do
    # lightning_bolt has active reservations
    csv = <<~CSV
      Count,Tradelist Count,Name,Edition,Condition,Language,Foil,Tags,Last Modified,Collector Number,Alter,Proxy,Purchase Price
      2,,Counterspell,ice,Good (Lightly Played),English,,,2026-01-01,64,,,
    CSV

    service = StockReconciliationService.new(
      uploaded_file(csv), mode: :full, format: :moxfield, seller: @seller
    )
    result = service.call

    assert result.success
    assert result.reservation_conflicts.any?
  end

  private

  def uploaded_file(content)
    StringIO.new(content)
  end
end
