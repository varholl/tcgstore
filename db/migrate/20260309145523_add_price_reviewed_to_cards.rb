class AddPriceReviewedToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :price_reviewed, :boolean, default: false, null: false
  end
end
