require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  # --- Validations ---

  test "message cannot exceed 1000 characters" do
    reservation = Reservation.new(user: users(:alice), status: :pending, message: "x" * 1001)
    assert_not reservation.valid?
    assert reservation.errors[:message].any?
  end

  test "guest reservation requires guest_name and guest_contact" do
    reservation = Reservation.new(status: :pending, guest_name: nil, guest_contact: nil)
    assert_not reservation.valid?
    assert reservation.errors[:guest_name].any?
    assert reservation.errors[:guest_contact].any?
  end

  test "user reservation does not require guest fields" do
    reservation = Reservation.new(user: users(:alice), status: :pending)
    assert reservation.valid?
  end

  # --- guest? ---

  test "guest? returns true when user_id is blank" do
    assert reservations(:guest_reservation).guest?
  end

  test "guest? returns false when user is present" do
    assert_not reservations(:pending_reservation).guest?
  end

  # --- display methods ---

  test "display_name returns user name for user reservations" do
    assert_equal "Alice", reservations(:pending_reservation).display_name
  end

  test "display_name returns guest_name for guest reservations" do
    assert_equal "Walk-in Customer", reservations(:guest_reservation).display_name
  end

  # --- total_price ---

  test "total_price returns final_price when set" do
    reservation = reservations(:pending_reservation)
    reservation.final_price = 99.99
    assert_equal 99.99, reservation.total_price
  end

  test "total_price sums items when final_price is blank" do
    reservation = reservations(:pending_reservation)
    # pending_bolt: qty 2 x $5.00 = $10.00
    assert_equal 10.00, reservation.total_price
  end

  # --- remaining_balance ---

  test "remaining_balance is total minus payments" do
    reservation = reservations(:pending_reservation)
    reservation.reservation_payments.create!(amount: 3.00)
    assert_equal 7.00, reservation.remaining_balance
  end

  # --- item preparation tracking ---

  test "prepared_items_count and flagged_items_count reflect item flags" do
    reservation = reservations(:pending_reservation)
    assert_equal 0, reservation.prepared_items_count
    assert_equal 0, reservation.flagged_items_count

    reservation.reservation_items.first.update!(prepared: true, issue: "out_of_stock")
    reservation.reload

    assert_equal 1, reservation.prepared_items_count
    assert_equal 1, reservation.flagged_items_count
  end

  # --- status enum ---

  test "status enum values" do
    assert reservations(:pending_reservation).pending?
    assert reservations(:in_preparation_reservation).in_preparation?
    assert reservations(:prepared_reservation).prepared?
    assert reservations(:paid_reservation).paid?
    assert reservations(:fulfilled_reservation).fulfilled?
    assert reservations(:cancelled_reservation).cancelled?
  end
end
