class AddPriceToCards < ActiveRecord::Migration[6.1]
  def change
    add_column :cards, :price, :decimal, precision: 10, scale: 2
  end
end
