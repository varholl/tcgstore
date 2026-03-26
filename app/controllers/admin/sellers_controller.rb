class Admin::SellersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_seller, only: [:edit, :update, :destroy]

  def index
    @sellers = Seller.order(:name)
  end

  def new
    @seller = Seller.new
  end

  def create
    @seller = Seller.new(seller_params)

    if @seller.save
      redirect_to admin_sellers_path, notice: t("controllers.admin.sellers.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @seller.update(seller_params)
      redirect_to admin_sellers_path, notice: t("controllers.admin.sellers.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @seller.cards.where("quantity > 0").exists?
      redirect_to admin_sellers_path, alert: t("controllers.admin.sellers.cannot_delete_with_stock")
    else
      @seller.destroy
      redirect_to admin_sellers_path, notice: t("controllers.admin.sellers.deleted")
    end
  end

  private

  def set_seller
    @seller = Seller.find(params[:id])
  end

  def seller_params
    params.require(:seller).permit(:name, :email, :user_id, :default)
  end

  def require_admin
    redirect_to root_path, alert: t("controllers.admin.cards.access_denied") unless current_user.admin?
  end
end
