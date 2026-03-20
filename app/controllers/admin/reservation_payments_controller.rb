class Admin::ReservationPaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def create
    @reservation = Reservation.find(params[:reservation_id])

    unless @reservation.prepared?
      redirect_to admin_reservation_path(@reservation), alert: t('controllers.admin.reservation_payments.not_prepared')
      return
    end

    payment = @reservation.reservation_payments.build(
      amount: params[:amount],
      note: params[:note]
    )

    if payment.save
      redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservation_payments.created')
    else
      redirect_to admin_reservation_path(@reservation), alert: payment.errors.full_messages.join(", ")
    end
  end

  def destroy
    @reservation = Reservation.find(params[:reservation_id])
    payment = @reservation.reservation_payments.find(params[:id])
    payment.destroy!
    redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservation_payments.deleted')
  end

  private

  def require_admin
    redirect_to root_path, alert: t('controllers.admin.reservations.access_denied') unless current_user.admin?
  end
end
