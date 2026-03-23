class WishlistsController < ApplicationController
  def index
  end

  def search
    if params[:wishlist].blank?
      redirect_to wishlists_path, alert: t("wishlists.empty_list")
      return
    end

    @wishlist_text = params[:wishlist]
    @results = WishlistMatcherService.call(@wishlist_text)
    @found_count = @results.count { |r| r[:cards].any? }
    @not_found_count = @results.count { |r| r[:cards].empty? }
  end
end
