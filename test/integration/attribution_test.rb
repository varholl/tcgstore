require "test_helper"

class AttributionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def attribution_cookie
    raw = cookies[ApplicationController::ATTRIBUTION_COOKIE.to_s]
    return nil if raw.blank?
    JSON.parse(raw).symbolize_keys
  end

  test "captures utm_source into the attribution cookie" do
    get cards_path, params: { utm_source: "moxfield", utm_campaign: "spring" }
    attr = attribution_cookie
    assert_not_nil attr
    assert_equal "moxfield", attr[:source]
    assert_equal "spring", attr[:campaign]
  end

  test "captures external referrer into the attribution cookie" do
    get cards_path, headers: { "HTTP_REFERER" => "https://deckbox.org/sets/123" }
    attr = attribution_cookie
    assert_not_nil attr
    assert_equal "https://deckbox.org/sets/123", attr[:referrer]
  end

  test "ignores same-host referrers" do
    get cards_path, headers: { "HTTP_REFERER" => "http://www.example.com/some/path" }
    assert_nil attribution_cookie
  end

  test "first-touch is preserved across visits without new utm_source" do
    get cards_path, params: { utm_source: "moxfield" }
    assert_equal "moxfield", attribution_cookie[:source]

    # Later visit from a different external referrer (no utm) should not clobber
    get cards_path, headers: { "HTTP_REFERER" => "https://google.com/" }
    assert_equal "moxfield", attribution_cookie[:source]
  end

  test "new utm_source overwrites a prior first-touch" do
    get cards_path, params: { utm_source: "moxfield" }
    assert_equal "moxfield", attribution_cookie[:source]

    get cards_path, params: { utm_source: "deckbox", utm_campaign: "promo" }
    assert_equal "deckbox", attribution_cookie[:source]
    assert_equal "promo", attribution_cookie[:campaign]
  end

  test "backfills user attribution from cookie on signed-in request" do
    user = users(:alice)
    assert_nil user.acquisition_source

    # First, anonymous visit with utm — sets cookie
    get cards_path, params: { utm_source: "moxfield", utm_campaign: "spring" }

    # Then sign in and visit any page — should backfill the user
    sign_in user
    get cards_path

    user.reload
    assert_equal "moxfield", user.acquisition_source
    assert_equal "spring", user.acquisition_campaign
    assert_not_nil user.acquired_at
  end

  test "does not overwrite existing user acquisition_source" do
    user = users(:alice)
    user.update_columns(
      acquisition_source: "original_partner",
      acquired_at: 1.month.ago
    )

    get cards_path, params: { utm_source: "different_partner" }
    sign_in user
    get cards_path

    user.reload
    assert_equal "original_partner", user.acquisition_source
  end
end
