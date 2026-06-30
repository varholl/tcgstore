require "test_helper"

class Admin::AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin_user)
  end

  test "index renders" do
    Announcement.create!(body: "Hello", level: "info")
    get admin_announcements_path
    assert_response :success
  end

  test "new renders the form" do
    get new_admin_announcement_path
    assert_response :success
    assert_select "select[name=?]", "announcement[level]"
    assert_select "textarea[name=?]", "announcement[body]"
  end

  test "create persists and redirects" do
    assert_difference "Announcement.count", 1 do
      post admin_announcements_path, params: { announcement: { title: "Promo", body: "20% off", level: "success", active: "1" } }
    end
    assert_redirected_to admin_announcements_path
    a = Announcement.order(:created_at).last
    assert_equal "success", a.level
    assert a.active?
  end

  test "create rejects a blank body" do
    assert_no_difference "Announcement.count" do
      post admin_announcements_path, params: { announcement: { body: "", level: "info" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit and update" do
    a = Announcement.create!(body: "Old", level: "info")
    get edit_admin_announcement_path(a)
    assert_response :success

    patch admin_announcement_path(a), params: { announcement: { body: "New", level: "warning" } }
    assert_redirected_to admin_announcements_path
    assert_equal "New", a.reload.body
    assert_equal "warning", a.level
  end

  test "toggle_active flips the flag" do
    a = Announcement.create!(body: "X", level: "info", active: true)
    patch toggle_active_admin_announcement_path(a)
    assert_not a.reload.active?
  end

  test "destroy removes it" do
    a = Announcement.create!(body: "X", level: "info")
    assert_difference "Announcement.count", -1 do
      delete admin_announcement_path(a)
    end
  end

  test "non-admin is blocked" do
    sign_in users(:alice)
    get admin_announcements_path
    assert_redirected_to root_path
  end
end
