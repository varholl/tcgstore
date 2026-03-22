class ReservationNotesController < ApplicationController
  before_action :authenticate_user!

  def create
    @reservation = current_user.reservations.find(params[:reservation_id])
    @reservation.reservation_notes.create!(body: params[:body], public: true, user: current_user)
    ReservationMailer.new_public_note(@reservation, current_user).deliver_later
    redirect_to reservation_path(@reservation, anchor: "notes"), notice: t('controllers.reservation_notes.created')
  end
end
