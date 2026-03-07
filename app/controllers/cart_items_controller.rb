class CartItemsController < ApplicationController
  before_action :authenticate_user!

  def index
    @cart_items = current_user.cart_items.includes(:card)
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
      respond_to do |format|
        format.html { redirect_back fallback_location: cards_path, notice: "#{@card.name} added to cart." }
        format.js
      end
    else
      redirect_back fallback_location: cards_path, alert: "Could not add card to cart."
    end
  end

  def update
    @cart_item = current_user.cart_items.find(params[:id])
    if @cart_item.update(quantity: params[:cart_item][:quantity])
      redirect_to cart_items_path, notice: "Cart updated."
    else
      redirect_to cart_items_path, alert: "Could not update quantity."
    end
  end

  def destroy
    @cart_item = current_user.cart_items.find(params[:id])
    @cart_item.destroy
    redirect_to cart_items_path, notice: "Item removed from cart."
  end
end
