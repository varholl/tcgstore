class Admin::ReservationNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def create
    @reservation = Reservation.find(params[:reservation_id])
    @reservation.reservation_notes.create!(body: params[:body])
    redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservation_notes.created')
  end

  private

  def require_admin
    redirect_to root_path, alert: t('controllers.admin.reservations.access_denied') unless current_user.admin?
  end
end
