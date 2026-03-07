class Admin::ReservationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    @reservations = Reservation.includes(:user).order(created_at: :desc)
    @reservations = @reservations.where(status: params[:status]) if params[:status].present? && Reservation.statuses.key?(params[:status])
    @reservations = @reservations.page(params[:page]).per(20)
  end

  def show
    @reservation = Reservation.includes(:user, reservation_items: :card).find(params[:id])
  end

  def fulfill
    @reservation = Reservation.find(params[:id])

    if @reservation.pending?
      @reservation.update!(status: :fulfilled)
      redirect_to admin_reservation_path(@reservation), notice: "Reservation marked as fulfilled."
    else
      redirect_to admin_reservation_path(@reservation), alert: "Only pending reservations can be fulfilled."
    end
  end

  def expire
    @reservation = Reservation.find(params[:id])

    if @reservation.pending?
      @reservation.update!(status: :expired)
      redirect_to admin_reservation_path(@reservation), notice: "Reservation marked as expired."
    else
      redirect_to admin_reservation_path(@reservation), alert: "Only pending reservations can be expired."
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: "Access denied." unless current_user.admin?
  end
end
