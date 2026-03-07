class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if params[:user][:password].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end

    if @user.update(profile_params)
      bypass_sign_in(@user) if params[:user][:password].present?
      redirect_to edit_profile_path, notice: "Profile updated successfully."
    else
      render :edit
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email, :phone_number, :password, :password_confirmation)
  end
end
