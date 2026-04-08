require "test_helper"

module Api
  class CardsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @key = "test-api-key-123"
      creds = Rails.application.credentials
      creds.define_singleton_method(:api_cards_key) { "test-api-key-123" }
    end

    teardown do
      creds = Rails.application.credentials
      creds.singleton_class.send(:remove_method, :api_cards_key) if creds.singleton_class.method_defined?(:api_cards_key)
    end

    def stub_no_credential(&block)
      creds = Rails.application.credentials
      creds.define_singleton_method(:api_cards_key) { nil }
      yield
    ensure
      creds.define_singleton_method(:api_cards_key) { "test-api-key-123" }
    end

    def auth_headers(key = @key)
      { "X-Api-Key" => key }
    end

    test "returns 401 without an api key" do
      get "/api/cards", params: { q: "lightning" }
      assert_response :unauthorized
      assert_equal "unauthorized", JSON.parse(response.body)["error"]
    end

    test "returns 401 with a wrong api key" do
      get "/api/cards", params: { q: "lightning" }, headers: auth_headers("nope")
      assert_response :unauthorized
    end

    test "returns 401 when api_cards_key credential is not set" do
      stub_no_credential do
        get "/api/cards", params: { q: "lightning" }, headers: auth_headers("anything")
        assert_response :unauthorized
      end
    end

    test "returns matching cards with the expected shape" do
      get "/api/cards", params: { q: "lightning" }, headers: auth_headers
      assert_response :success

      body = JSON.parse(response.body)
      assert_kind_of Array, body["data"]

      card = cards(:lightning_bolt)
      result = body["data"].find { |r| r["id"] == card.id }
      refute_nil result, "expected lightning_bolt in results"

      assert_equal card.name, result["title"]
      assert_equal card.price.to_s, result["price"].to_s
      assert_nil result["imageUrl"]

      assert_equal card.condition, result["condition"]
      assert_equal card.edition_name, result["expansion"]
      assert_equal "no", result["foil"]
      assert_equal card.language, result["language"]
      assert_equal card.scryfall_id.to_s, result["scryfall_id"].to_s
      # quantity is available stock = quantity - active reservations (2 + 1 from fixtures)
      assert_equal 1, result["quantity"]
    end

    test "excludes cards from suspended sellers" do
      get "/api/cards", params: { q: "lightning" }, headers: auth_headers
      assert_response :success
      ids = JSON.parse(response.body)["data"].map { |r| r["id"] }
      assert_includes ids, cards(:lightning_bolt).id
      refute_includes ids, cards(:lightning_bolt_other_seller).id
    end

    test "excludes cards with zero stock" do
      get "/api/cards", params: { q: "Empty" }, headers: auth_headers
      assert_response :success
      assert_empty JSON.parse(response.body)["data"]
    end

    test "subtracts active reservations from quantity and skips fully reserved" do
      card = cards(:lightning_bolt)
      # Fixtures already reserve 3 of 4; add 1 more to fully consume stock
      ReservationItem.create!(
        reservation: reservations(:pending_reservation),
        card: card,
        quantity: 1,
        unit_price: card.price
      )

      get "/api/cards", params: { q: "lightning" }, headers: auth_headers
      assert_response :success
      ids = JSON.parse(response.body)["data"].map { |r| r["id"] }
      refute_includes ids, card.id
    end

    test "marks foil cards as si" do
      cards(:counterspell).update!(foil: "foil")
      get "/api/cards", params: { q: "Counterspell" }, headers: auth_headers
      assert_response :success
      result = JSON.parse(response.body)["data"].find { |r| r["id"] == cards(:counterspell).id }
      assert_equal "si", result["foil"]
    end

    test "respects per_page and caps at 100" do
      get "/api/cards", params: { q: "lightning", per_page: 9999 }, headers: auth_headers
      assert_response :success
      assert_equal 100, JSON.parse(response.body)["per_page"]
    end

    test "groups duplicate listings into a single result and sums their quantities" do
      original = cards(:lightning_bolt)
      duplicate = Card.create!(
        name: original.name,
        edition: original.edition,
        edition_name: original.edition_name,
        collector_number: original.collector_number,
        condition: original.condition,
        language: original.language,
        foil: original.foil,
        quantity: 5,
        price: original.price,
        seller: original.seller
      )

      get "/api/cards", params: { q: "lightning" }, headers: auth_headers
      assert_response :success

      data = JSON.parse(response.body)["data"]
      lightning_results = data.select { |r| r["title"] == "Lightning Bolt" }
      assert_equal 1, lightning_results.size, "expected lightning bolts to be grouped into one row"

      # original has 4 stock, duplicate has 5 stock, fixtures reserve 3 → 6 available
      assert_equal 6, lightning_results.first["quantity"]
      assert_includes [original.id, duplicate.id], lightning_results.first["id"]
    end

    test "returns empty data when query matches nothing" do
      get "/api/cards", params: { q: "zzznotacardzzz" }, headers: auth_headers
      assert_response :success
      assert_empty JSON.parse(response.body)["data"]
    end
  end
end
