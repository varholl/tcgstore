require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  def card_titles
    css_select("turbo-frame#cards-list h6.card-title").map { |n| n.text.strip }
  end

  test "index searches by ?search= param" do
    get cards_path, params: { search: "Lightning Bolt" }
    assert_response :success
    assert_includes card_titles, "Lightning Bolt"
    assert_not_includes card_titles, "Counterspell"
  end

  test "index searches by ?q= param as alias for search" do
    get cards_path, params: { q: "Lightning Bolt" }
    assert_response :success
    assert_includes card_titles, "Lightning Bolt"
    assert_not_includes card_titles, "Counterspell"
  end

  test "index prefers ?search= over ?q= when both are provided" do
    get cards_path, params: { search: "Lightning Bolt", q: "Counterspell" }
    assert_response :success
    assert_includes card_titles, "Lightning Bolt"
    assert_not_includes card_titles, "Counterspell"
  end

  test "/search redirects to /cards preserving the query string" do
    get "/search", params: { q: "Lightning Bolt" }
    assert_redirected_to "/cards?q=Lightning+Bolt"
    follow_redirect!
    assert_includes card_titles, "Lightning Bolt"
    assert_not_includes card_titles, "Counterspell"
  end

  test "index falls back to ?q= when ?search= is blank" do
    get cards_path, params: { search: "", q: "Counterspell" }
    assert_response :success
    assert_includes card_titles, "Counterspell"
    assert_not_includes card_titles, "Lightning Bolt"
  end
end
