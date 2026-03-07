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
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.fulfilled')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.fulfill_error')
    end
  end

  def expire
    @reservation = Reservation.find(params[:id])

    if @reservation.pending?
      @reservation.update!(status: :expired)
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservations.expired')
    else
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservations.expire_error')
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: t('controllers.admin.reservations.access_denied') unless current_user.admin?
  end
end
