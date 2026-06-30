require "test_helper"

class AnnouncementsBannerTest < ActionDispatch::IntegrationTest
  test "visible announcement shows on a public page to logged-out visitors" do
    a = Announcement.create!(title: "Heads up", body: "We are open this weekend!", level: "success")
    get root_path
    assert_response :success
    assert_select ".announcement-banner[data-announcement-key-value=?]", "announcement-#{a.id}-#{a.updated_at.to_i}"
    assert_match "We are open this weekend!", response.body
  end

  test "inactive announcement is not shown" do
    Announcement.create!(body: "Should not show", level: "info", active: false)
    get root_path
    assert_no_match "Should not show", response.body
  end

  test "scheduled-for-later announcement is not shown yet" do
    Announcement.create!(body: "Future news", level: "info", starts_at: 1.day.from_now)
    get root_path
    assert_no_match "Future news", response.body
  end

  test "expired announcement is not shown" do
    Announcement.create!(body: "Old news", level: "info", ends_at: 1.day.ago)
    get root_path
    assert_no_match "Old news", response.body
  end
end
