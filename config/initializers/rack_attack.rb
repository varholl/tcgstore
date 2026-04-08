class Rack::Attack
  # Cache store: use Rails cache (memory store in dev, configure in prod as needed)
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Throttle the cards API by IP: 60 requests per minute
  throttle("api/cards/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/cards")
  end

  # Throttle by API key (defense against a leaked key being abused): 120 req/min
  throttle("api/cards/key", limit: 120, period: 1.minute) do |req|
    if req.path.start_with?("/api/cards")
      req.get_header("HTTP_X_API_KEY").presence
    end
  end

  self.throttled_responder = lambda do |_req|
    [429, { "Content-Type" => "application/json" }, [{ error: "rate_limited" }.to_json]]
  end
end
