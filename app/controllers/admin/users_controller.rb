class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
    @users = User.where(admin: false).order(created_at: :desc)
    if params[:search].present?
      search = "%#{params[:search]}%"
      @users = @users.where("name ILIKE :q OR email ILIKE :q", q: search)
    end
    @users = @users.page(params[:page]).per(20)
  end

  def show
    @reservations = @user.reservations.order(created_at: :desc)
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: t('controllers.admin.users.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: t('controllers.admin.users.deleted')
  end

  private

  def set_user
    @user = User.where(admin: false).find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :phone_number)
  end

  def require_admin
    redirect_to root_path, alert: t('controllers.admin.users.access_denied') unless current_user.admin?
  end
end
