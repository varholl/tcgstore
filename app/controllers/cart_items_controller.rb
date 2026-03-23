class CartItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_no_maintenance!, only: [:create, :update]

  def index
    @cart_items = current_user.cart_items.includes(:card)
    card_ids = @cart_items.map(&:card_id)
    @reserved_quantities = ReservationItem
      .joins(:reservation)
      .where(reservations: { status: %w[pending paid] }, card_id: card_ids)
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
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("cart_badge", cart_badge_html)
        end
        format.html { redirect_back fallback_location: cards_path, notice: t('controllers.cart_items.added', name: @card.name) }
      end
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

  def bulk_add
    card_ids = params[:card_ids] || []
    added = 0

    card_ids.each do |card_id|
      card = Card.find_by(id: card_id)
      next unless card

      cart_item = current_user.cart_items.find_or_initialize_by(card: card)
      available = card.available_quantity
      current_in_cart = cart_item.persisted? ? cart_item.quantity : 0
      new_quantity = current_in_cart + 1
      new_quantity = [new_quantity, available].min
      next if new_quantity <= 0

      cart_item.quantity = new_quantity
      added += 1 if cart_item.save
    end

    redirect_back fallback_location: cards_path, notice: t('controllers.cart_items.bulk_added', count: added)
  end

  def destroy_all
    current_user.cart_items.destroy_all
    redirect_to cart_items_path, notice: t('controllers.cart_items.cleared')
  end

  private

  def cart_badge_html
    count = current_user.cart_items.sum(:quantity)
    count > 0 ? "<span class=\"badge bg-primary rounded-pill\">#{count}</span>" : ""
  end
end
