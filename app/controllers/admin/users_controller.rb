class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
    @users = User.where(admin: false).order(created_at: :desc)
    if params[:search].present?
      search = "%#{params[:search]}%"
      @users = @users.where("name LIKE :q OR email LIKE :q", q: search)
    end
    @users = @users.page(params[:page]).per(20)
  end

  def show
    @reservations = @user.reservations.includes(:reservation_items).order(created_at: :desc)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    password = Devise.friendly_token[0, 20]
    @user.password = password
    @user.skip_confirmation!

    if @user.save
      redirect_to admin_user_path(@user), notice: t('controllers.admin.users.created')
    else
      render :new, status: :unprocessable_entity
    end
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
    if @user.reservations.where(status: "fulfilled").exists?
      redirect_to admin_user_path(@user), alert: t('controllers.admin.users.cannot_delete_fulfilled')
    else
      @user.destroy
      redirect_to admin_users_path, notice: t('controllers.admin.users.deleted')
    end
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
