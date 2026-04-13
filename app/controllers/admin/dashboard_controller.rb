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

    # Attribution (last 30 days)
    since = 30.days.ago
    @attribution_users_by_source = User
      .where("acquired_at >= ?", since)
      .where.not(acquisition_source: [nil, ""])
      .group(:acquisition_source)
      .order(Arel.sql("COUNT(*) DESC"))
      .count
    @attribution_reservations_by_source = Reservation
      .where("created_at >= ?", since)
      .where.not(source: [nil, ""])
      .group(:source)
      .order(Arel.sql("COUNT(*) DESC"))
      .count
    @attribution_total_users = @attribution_users_by_source.values.sum
    @attribution_total_reservations = @attribution_reservations_by_source.values.sum
  end

  def search_cards
    @cards = Card.search_by_name(params[:query]).limit(20)
    render partial: "walk_in_search_results", locals: { cards: @cards }
  end

  def walk_in
    card = Card.find(params[:card_id])
    quantity = [params[:quantity].to_i, 1].max

    creator = AdminReservationCreator.new(
      guest_name: t("admin.dashboard.walk_in.default_guest_name"),
      guest_contact: t("admin.dashboard.walk_in.default_guest_contact"),
      items: [{ card_id: card.id, quantity: quantity }]
    )

    if creator.call
      redirect_to admin_reservation_path(creator.reservation), notice: t("admin.dashboard.walk_in.created")
    else
      redirect_to admin_dashboard_path, alert: t("admin.dashboard.walk_in.unavailable")
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: t('controllers.admin.reservations.access_denied') unless current_user.admin?
  end
end
