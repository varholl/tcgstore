require "test_helper"

class ReservationMailerTest < ActionMailer::TestCase
  test "in_preparation emails the reservation owner" do
    reservation = reservations(:pending_reservation)
    email = ReservationMailer.in_preparation(reservation)

    assert_equal [reservation.user.email], email.to
    assert_emails 1 do
      email.deliver_now
    end
  end

  test "in_preparation does not email guest reservations" do
    reservation = reservations(:guest_reservation)

    assert_emails 0 do
      ReservationMailer.in_preparation(reservation).deliver_now
    end
  end
end
