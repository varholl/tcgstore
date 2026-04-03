require "test_helper"

class ReservationCreatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
  end

  test "returns false with empty cart" do
    creator = ReservationCreator.new(@user)
    assert_not creator.call
  end

  test "creates reservation from cart items" do
    @user.cart_items.create!(card: cards(:counterspell), quantity: 1)

    creator = ReservationCreator.new(@user, message: "Please hold these")
    assert creator.call

    reservation = creator.reservation
    assert reservation.pending?
    assert_equal "Please hold these", reservation.message
    assert_equal 1, reservation.reservation_items.count
    assert_equal 0, @user.cart_items.count
  end

  test "sets unit_price from card price" do
    @user.cart_items.create!(card: cards(:counterspell), quantity: 1)

    creator = ReservationCreator.new(@user)
    creator.call

    item = creator.reservation.reservation_items.first
    assert_equal cards(:counterspell).price, item.unit_price
  end

  test "fails when requested quantity exceeds available" do
    @user.cart_items.create!(card: cards(:lightning_bolt), quantity: 5)

    creator = ReservationCreator.new(@user)
    assert_not creator.call
    assert creator.unavailable_items.any?
    assert_nil creator.reservation
    # Cart should not be cleared
    assert_equal 1, @user.cart_items.count
  end

  test "distributes across sellers using FIFO" do
    # counterspell has 2 qty, no reservations, single seller
    @user.cart_items.create!(card: cards(:counterspell), quantity: 2)

    creator = ReservationCreator.new(@user)
    assert creator.call

    item = creator.reservation.reservation_items.find_by(card: cards(:counterspell))
    assert_equal 2, item.quantity
  end

  test "excludes suspended sellers from distribution" do
    bolt = cards(:lightning_bolt)
    # bolt has 4 qty on active seller, 2 on suspended
    # 3 already reserved (2 pending + 1 prepared), so only 1 available from active
    @user.cart_items.create!(card: bolt, quantity: 1)

    creator = ReservationCreator.new(@user)
    assert creator.call

    items = creator.reservation.reservation_items
    items.each do |item|
      assert_not item.card.seller.suspended?
    end
  end

  test "works with preorder cards" do
    @user.cart_items.create!(card: cards(:preorder_card), quantity: 2)

    creator = ReservationCreator.new(@user)
    assert creator.call

    item = creator.reservation.reservation_items.first
    assert_equal 2, item.quantity
    assert item.card.preorder?
  end

  test "succeeds and creates reservation on valid cart" do
    @user.cart_items.create!(card: cards(:counterspell), quantity: 1)

    creator = ReservationCreator.new(@user)
    assert creator.call
    assert creator.success?
    assert_not_nil creator.reservation
  end

  test "failure leaves no reservation" do
    @user.cart_items.create!(card: cards(:lightning_bolt), quantity: 100)

    creator = ReservationCreator.new(@user)
    assert_not creator.call
    assert_not creator.success?
  end
end
