require "test_helper"

class CardTest < ActiveSupport::TestCase
  # --- Validations ---

  test "requires a name" do
    card = Card.new(name: nil, quantity: 1, seller: sellers(:default_seller))
    assert_not card.valid?
    assert card.errors[:name].any?
  end

  test "quantity cannot be negative" do
    card = cards(:lightning_bolt)
    card.quantity = -1
    assert_not card.valid?
  end

  test "quantity can be zero" do
    card = cards(:lightning_bolt)
    card.quantity = 0
    assert card.valid?
  end

  # --- preorder? ---

  test "preorder? returns true when release_date is in the future" do
    assert cards(:preorder_card).preorder?
  end

  test "preorder? returns false when release_date is in the past" do
    assert_not cards(:past_release_card).preorder?
  end

  test "preorder? returns false when release_date is nil" do
    assert_not cards(:lightning_bolt).preorder?
  end

  test "preorder? returns false when release_date is today" do
    card = cards(:preorder_card)
    card.release_date = Date.current
    assert_not card.preorder?
  end

  test "preorder? uses Buenos Aires timezone" do
    # Date.current respects config.time_zone (Buenos Aires)
    card = cards(:lightning_bolt)
    card.release_date = Date.current + 1
    assert card.preorder?

    card.release_date = Date.current
    assert_not card.preorder?
  end

  # --- card_identity ---

  test "card_identity groups cards by edition, collector_number, condition, language, foil" do
    bolt = cards(:lightning_bolt)
    bolt_other = cards(:lightning_bolt_other_seller)
    assert_equal bolt.card_identity, bolt_other.card_identity
  end

  test "card_identity differs for different conditions" do
    bolt = cards(:lightning_bolt)
    counterspell = cards(:counterspell)
    assert_not_equal bolt.card_identity, counterspell.card_identity
  end

  # --- sibling_cards ---

  test "sibling_cards finds cards with same identity across sellers" do
    bolt = cards(:lightning_bolt)
    siblings = bolt.sibling_cards
    assert_includes siblings, cards(:lightning_bolt_other_seller)
    assert_includes siblings, bolt
  end

  # --- active_sibling_cards ---

  test "active_sibling_cards excludes suspended sellers" do
    bolt = cards(:lightning_bolt)
    active = bolt.active_sibling_cards
    assert_includes active, bolt
    assert_not_includes active, cards(:lightning_bolt_other_seller)
  end

  # --- available_quantity ---

  test "available_quantity subtracts reserved quantities" do
    bolt = cards(:lightning_bolt)
    # bolt has qty 4, pending_bolt reserves 2, prepared_bolt reserves 1
    assert_equal 1, bolt.available_quantity
  end

  test "available_quantity returns 0 for suspended sellers" do
    bolt_suspended = cards(:lightning_bolt_other_seller)
    assert_equal 0, bolt_suspended.available_quantity
  end

  test "available_quantity ignores fulfilled and cancelled reservations" do
    counterspell = cards(:counterspell)
    # no active reservations on counterspell
    assert_equal 2, counterspell.available_quantity
  end

  # --- grouped_available_quantity ---

  test "grouped_available_quantity sums across active siblings only" do
    bolt = cards(:lightning_bolt)
    # Only default_seller is active (qty 4), suspended seller excluded
    # 3 reserved (2 pending + 1 prepared)
    assert_equal 1, bolt.grouped_available_quantity
  end

  # --- foil_display ---

  test "foil_display returns Foil by default" do
    card = Card.new
    assert_equal "Foil", card.foil_display
  end

  test "foil_display returns Surge Foil" do
    card = Card.new(foil_type: "surge")
    assert_equal "Surge Foil", card.foil_display
  end

  test "foil_display returns Etched Foil" do
    card = Card.new(foil_type: "etched")
    assert_equal "Etched Foil", card.foil_display
  end

  # --- touch_last_stocked_at ---

  test "updates last_stocked_at when quantity increases" do
    card = cards(:counterspell)
    card.update!(last_stocked_at: 1.week.ago)
    card.update!(quantity: card.quantity + 1)
    assert_in_delta Time.current, card.last_stocked_at, 2
  end

  test "does not update last_stocked_at when quantity decreases" do
    card = cards(:counterspell)
    original = 1.week.ago
    card.update!(last_stocked_at: original)
    card.update!(quantity: card.quantity - 1)
    assert_in_delta original, card.last_stocked_at, 2
  end
end
