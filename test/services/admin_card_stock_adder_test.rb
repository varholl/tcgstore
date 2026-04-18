require "test_helper"

class AdminCardStockAdderTest < ActiveSupport::TestCase
  setup do
    @seller = sellers(:default_seller)
  end

  test "creates a new card" do
    params = {
      name: "Mox Pearl",
      scryfall_id: "abc123",
      set_code: "lea",
      set_name: "Limited Edition Alpha",
      collector_number: "999",
      condition: "NM",
      language: "English",
      foil: "",
      quantity: "3",
      price: "100.00",
      seller_id: @seller.id
    }

    adder = AdminCardStockAdder.new(params)
    assert_equal :added, adder.call

    card = adder.card
    assert_equal "Mox Pearl", card.name
    assert_equal 3, card.quantity
    assert_equal 100.00, card.price.to_f
    assert_equal 1, card.stock_entries.count
  end

  test "increments existing card quantity" do
    bolt = cards(:lightning_bolt)
    original_qty = bolt.quantity

    params = {
      name: bolt.name,
      set_code: bolt.edition,
      collector_number: bolt.collector_number,
      condition: bolt.condition,
      language: bolt.language,
      foil: bolt.foil.to_s,
      quantity: "2",
      seller_id: bolt.seller_id
    }

    adder = AdminCardStockAdder.new(params)
    assert_equal :incremented, adder.call

    bolt.reload
    assert_equal original_qty + 2, bolt.quantity
  end

  test "creates card with release_date" do
    params = {
      name: "New Set Card",
      set_code: "test",
      set_name: "Test Set",
      collector_number: "1",
      condition: "NM",
      language: "English",
      foil: "",
      quantity: "1",
      price: "10.00",
      seller_id: @seller.id,
      release_date: 7.days.ago.to_date.to_s
    }

    adder = AdminCardStockAdder.new(params)
    assert_equal :added, adder.call
    assert adder.card.from_new_set?
  end

  test "finds existing card by scryfall_id" do
    bolt = cards(:lightning_bolt)
    bolt.update_column(:scryfall_id, "scry-bolt-123")

    params = {
      name: bolt.name,
      scryfall_id: "scry-bolt-123",
      set_code: bolt.edition,
      collector_number: bolt.collector_number,
      condition: bolt.condition,
      language: bolt.language,
      foil: bolt.foil.to_s,
      quantity: "1",
      seller_id: bolt.seller_id
    }

    adder = AdminCardStockAdder.new(params)
    assert_equal :incremented, adder.call
    assert_equal bolt.id, adder.card.id
  end

  test "backfills metadata on existing card" do
    bolt = cards(:lightning_bolt)
    bolt.update_columns(colors: nil, rarity: nil)

    params = {
      name: bolt.name,
      set_code: bolt.edition,
      collector_number: bolt.collector_number,
      condition: bolt.condition,
      language: bolt.language,
      foil: bolt.foil.to_s,
      quantity: "1",
      seller_id: bolt.seller_id,
      colors: "R",
      rarity: "common"
    }

    adder = AdminCardStockAdder.new(params)
    adder.call

    bolt.reload
    assert_equal "R", bolt.colors
    assert_equal "common", bolt.rarity
  end

  test "creates stock entry on new card" do
    params = {
      name: "Test Card",
      set_code: "tst",
      set_name: "Test",
      collector_number: "42",
      condition: "NM",
      language: "English",
      foil: "",
      quantity: "5",
      seller_id: @seller.id
    }

    adder = AdminCardStockAdder.new(params)
    adder.call

    entry = adder.card.stock_entries.last
    assert_equal 5, entry.quantity
  end
end
