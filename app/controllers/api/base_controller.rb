module Api
  class BaseController < ActionController::API
    before_action :authenticate_api_key!

    private

    def authenticate_api_key!
      provided = request.headers["X-Api-Key"].to_s
      expected = Rails.application.credentials.api_cards_key.to_s

      if expected.empty? || !ActiveSupport::SecurityUtils.secure_compare(provided, expected)
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end
  end
end
