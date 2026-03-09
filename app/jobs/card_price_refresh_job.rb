class CardPriceRefreshJob < ApplicationJob
  queue_as :default

  def perform
    CardPriceRefreshService.new.call
  end
end
