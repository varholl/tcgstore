class AddSellerToCards < ActiveRecord::Migration[8.0]
  def up
    add_reference :cards, :seller, foreign_key: true

    # Create default seller and assign all existing cards
    default_seller = Seller.find_or_create_by!(default: true) do |s|
      s.name = "Default"
    end
    Card.update_all(seller_id: default_seller.id)

    change_column_null :cards, :seller_id, false
  end

  def down
    remove_reference :cards, :seller
  end
end
