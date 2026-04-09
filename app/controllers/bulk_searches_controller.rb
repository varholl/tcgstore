class BulkSearchesController < ApplicationController
  def index
  end

  def search
    if params[:bulk_search].blank?
      redirect_to bulk_searches_path, alert: t("bulk_searches.empty_list")
      return
    end

    @bulk_search_text = params[:bulk_search]
    @results = BulkSearchMatcherService.call(@bulk_search_text)
    @found_count = @results.count { |r| r[:cards].any? }
    @not_found_count = @results.count { |r| r[:cards].empty? }
  end
end
