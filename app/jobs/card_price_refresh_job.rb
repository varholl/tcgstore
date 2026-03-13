class CardPriceRefreshJob < ApplicationJob
  queue_as :default

  def perform
    CardPriceRefreshService.new.call
    CardPriceFallbackJob.perform_later
  end
end
