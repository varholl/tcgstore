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

  # --- from_new_set? ---

  test "from_new_set? returns true when release_date is within the last 30 days" do
    assert cards(:new_set_card).from_new_set?
  end

  test "from_new_set? returns true when release_date is in the future" do
    card = cards(:new_set_card)
    card.release_date = 30.days.from_now.to_date
    assert card.from_new_set?
  end

  test "from_new_set? returns false when release_date is older than 30 days" do
    assert_not cards(:past_release_card).from_new_set?
  end

  test "from_new_set? returns false when release_date is nil" do
    assert_not cards(:lightning_bolt).from_new_set?
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

  test "available_quantity counts in_preparation reservations as reserved" do
    counterspell = cards(:counterspell)
    assert_equal 2, counterspell.available_quantity
    reservation = Reservation.create!(user: users(:alice), status: :in_preparation)
    reservation.reservation_items.create!(card: counterspell, quantity: 1, unit_price: counterspell.price)
    assert_equal 1, counterspell.reload.available_quantity
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
