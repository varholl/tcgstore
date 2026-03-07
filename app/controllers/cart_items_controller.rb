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

    available = @card.available_quantity
    current_in_cart = @cart_item.persisted? ? @cart_item.quantity : 0
    requested_add = (params[:quantity] || 1).to_i

    new_quantity = current_in_cart + requested_add
    new_quantity = [new_quantity, available].min

    if new_quantity <= 0
      redirect_back fallback_location: cards_path, alert: t('controllers.cart_items.add_error')
      return
    end

    @cart_item.quantity = new_quantity

    if @cart_item.save
      redirect_back fallback_location: cards_path, notice: t('controllers.cart_items.added', name: @card.name)
    else
      redirect_back fallback_location: cards_path, alert: t('controllers.cart_items.add_error')
    end
  end

  def update
    @cart_item = current_user.cart_items.find(params[:id])
    available = @cart_item.card.available_quantity
    new_quantity = [params[:cart_item][:quantity].to_i, available].min
    new_quantity = [new_quantity, 1].max

    if @cart_item.update(quantity: new_quantity)
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
