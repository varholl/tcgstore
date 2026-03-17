class Admin::StockReconciliationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def new
  end

  def export
    csv_data = StockExportService.new.call

    send_data csv_data,
      filename: "moxfield_export_#{Date.current.iso8601}.csv",
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
  end

  def create
    unless params[:file].present?
      redirect_to new_admin_stock_reconciliation_path, alert: t("admin.stock_reconciliations.no_file")
      return
    end

    mode = params[:mode] == "partial" ? :partial : :full
    service = StockReconciliationService.new(params[:file], mode: mode)
    @result = service.call
    @mode = mode

    if @result.success
      CardPriceRefreshJob.perform_later if @result.cards_created > 0
      render :result
    else
      redirect_to new_admin_stock_reconciliation_path, alert: @result.errors.join(", ")
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: t("controllers.admin.cards.access_denied") unless current_user.admin?
  end
end
