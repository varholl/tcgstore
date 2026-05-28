require "test_helper"

class ReservationItemTest < ActiveSupport::TestCase
  test "prepared defaults to false" do
    assert_not reservation_items(:pending_bolt).prepared?
  end

  test "accepts valid issue values" do
    item = reservation_items(:pending_bolt)
    item.issue = "wrong_condition"
    assert item.valid?
    assert item.wrong_condition?
  end

  test "rejects invalid issue values" do
    item = reservation_items(:pending_bolt)
    item.issue = "exploded"
    assert_not item.valid?
    assert item.errors[:issue].any?
  end

  test "issue can be nil when there is no problem" do
    item = reservation_items(:pending_bolt)
    item.issue = nil
    assert item.valid?
    assert_nil item.issue
  end

  test "issue_note cannot exceed 500 characters" do
    item = reservation_items(:pending_bolt)
    item.issue_note = "x" * 501
    assert_not item.valid?
    assert item.errors[:issue_note].any?
  end
end
