require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { sign_in users(:alice) }

  test "non-admin cannot remove an item from an in_preparation reservation" do
    reservation = reservations(:in_preparation_reservation)
    item = reservation.reservation_items.create!(card: cards(:counterspell), quantity: 1, unit_price: 1.00)

    assert_no_difference -> { reservation.reservation_items.count } do
      delete remove_item_reservation_path(reservation, item_id: item.id)
    end

    assert_redirected_to reservation_path(reservation)
  end

  test "non-admin can remove an item from a pending reservation" do
    reservation = reservations(:pending_reservation)
    item = reservation.reservation_items.create!(card: cards(:counterspell), quantity: 1, unit_price: 1.00)

    assert_difference -> { reservation.reservation_items.count }, -1 do
      delete remove_item_reservation_path(reservation, item_id: item.id)
    end
  end

  test "non-admin can add an item to an in_preparation reservation" do
    reservation = reservations(:in_preparation_reservation)

    assert_difference -> { reservation.reservation_items.count }, 1 do
      post add_item_reservation_path(reservation), params: { card_id: cards(:counterspell).id, quantity: 1 }
    end
  end
end
