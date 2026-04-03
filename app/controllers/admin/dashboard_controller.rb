class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    non_trade = Reservation.where(trade: false)
    trade = Reservation.where(trade: true)

    # Income: paid + shipped + fulfilled (non-trade)
    paid_reservations = non_trade.where(status: %w[paid shipped fulfilled])
    @total_income = paid_reservations.sum { |r| r.total_price }

    # Pending: pending + prepared (non-trade)
    pending_reservations = non_trade.where(status: %w[pending prepared])
    @pending_total = pending_reservations.sum { |r| r.total_price }
    @pending_count = pending_reservations.count

    # Breakdown
    @income_paid = non_trade.where(status: :paid).sum { |r| r.total_price }
    @income_paid_count = non_trade.where(status: :paid).count
    @income_shipped = non_trade.where(status: :shipped).sum { |r| r.total_price }
    @income_shipped_count = non_trade.where(status: :shipped).count
    @income_fulfilled = non_trade.where(status: :fulfilled).sum { |r| r.total_price }
    @income_fulfilled_count = non_trade.where(status: :fulfilled).count

    @pending_pending = non_trade.where(status: :pending).sum { |r| r.total_price }
    @pending_pending_count = non_trade.where(status: :pending).count
    @pending_prepared = non_trade.where(status: :prepared).sum { |r| r.total_price }
    @pending_prepared_count = non_trade.where(status: :prepared).count

    # Trades
    active_trades = trade.where(status: %w[pending prepared paid shipped fulfilled])
    @trade_total = active_trades.sum { |r| r.total_price }
    @trade_count = active_trades.count
  end

  private

  def require_admin
    redirect_to root_path, alert: t('controllers.admin.reservations.access_denied') unless current_user.admin?
  end
end
