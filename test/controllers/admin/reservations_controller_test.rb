require "test_helper"

class Admin::ReservationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @previous_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    sign_in users(:admin_user)
  end

  teardown do
    ActiveJob::Base.queue_adapter = @previous_queue_adapter
  end

  test "in_preparation transitions a pending reservation and notifies the customer" do
    reservation = reservations(:pending_reservation)

    assert_enqueued_emails 1 do
      patch in_preparation_admin_reservation_path(reservation)
    end

    assert reservation.reload.in_preparation?
    assert_redirected_to admin_reservation_path(reservation)
  end

  test "in_preparation is rejected for non-pending reservations" do
    reservation = reservations(:prepared_reservation)

    assert_no_enqueued_emails do
      patch in_preparation_admin_reservation_path(reservation)
    end

    assert reservation.reload.prepared?
  end

  test "prepare can transition from in_preparation to prepared" do
    reservation = reservations(:in_preparation_reservation)

    patch prepare_admin_reservation_path(reservation)

    assert reservation.reload.prepared?
    assert_redirected_to admin_reservation_path(reservation)
  end

  test "item prep controls render inside the reservation_items turbo frame" do
    get admin_reservation_path(reservations(:pending_reservation))
    assert_response :success
    assert_select "turbo-frame#reservation_items form[action*=?]", "toggle_item_prepared"
  end

  test "toggle_item_prepared flips the item's prepared flag" do
    item = reservation_items(:pending_bolt)
    assert_not item.prepared?

    patch toggle_item_prepared_admin_reservation_path(item.reservation, item_id: item.id)
    assert item.reload.prepared?

    patch toggle_item_prepared_admin_reservation_path(item.reservation, item_id: item.id)
    assert_not item.reload.prepared?
  end

  test "update_item_issue sets and clears the item's problem flag" do
    item = reservation_items(:pending_bolt)

    patch update_item_issue_admin_reservation_path(item.reservation, item_id: item.id),
      params: { issue: "out_of_stock", issue_note: "Only 1 left" }
    item.reload
    assert item.out_of_stock?
    assert_equal "Only 1 left", item.issue_note

    patch update_item_issue_admin_reservation_path(item.reservation, item_id: item.id),
      params: { issue: "", issue_note: "ignored" }
    item.reload
    assert_nil item.issue
    assert_nil item.issue_note
  end
end
