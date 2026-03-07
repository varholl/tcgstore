class CartItemsController < ApplicationController
  before_action :authenticate_user!

  def index
    @cart_items = current_user.cart_items.includes(:card)
    card_ids = @cart_items.map(&:card_id)
    @reserved_quantities = ReservationItem
      .joins(:reservation)
      .where(reservations: { status: "pending" }, card_id: card_ids)
      .group(:card_id)
      .sum(:quantity)
  end

  def create
    @card = Card.find(params[:card_id])
    @cart_item = current_user.cart_items.find_or_initialize_by(card: @card)

    if @cart_item.new_record?
      @cart_item.quantity = params[:quantity] || 1
    else
      @cart_item.quantity += (params[:quantity] || 1).to_i
    end

    if @cart_item.save
      redirect_back fallback_location: cards_path, notice: t('controllers.cart_items.added', name: @card.name)
    else
      redirect_back fallback_location: cards_path, alert: t('controllers.cart_items.add_error')
    end
  end

  def update
    @cart_item = current_user.cart_items.find(params[:id])
    if @cart_item.update(quantity: params[:cart_item][:quantity])
      redirect_to cart_items_path, notice: t('controllers.cart_items.updated')
    else
      redirect_to cart_items_path, alert: t('controllers.cart_items.update_error')
    end
  end

  def destroy
    @cart_item = current_user.cart_items.find(params[:id])
    @cart_item.destroy
    redirect_to cart_items_path, notice: t('controllers.cart_items.removed')
  end
end
