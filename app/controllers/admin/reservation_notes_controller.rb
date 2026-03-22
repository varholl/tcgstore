class Admin::ReservationNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def create
    @reservation = Reservation.find(params[:reservation_id])
    is_public = params[:public] == "true"
    @reservation.reservation_notes.create!(body: params[:body], public: is_public, user: current_user)

    if is_public && @reservation.user.present?
      ReservationMailer.new_public_note(@reservation, current_user).deliver_later
    end

    redirect_to admin_reservation_path(@reservation), notice: t('controllers.admin.reservation_notes.created')
  end

  private

  def require_admin
    redirect_to root_path, alert: t('controllers.admin.reservations.access_denied') unless current_user.admin?
  end
end
