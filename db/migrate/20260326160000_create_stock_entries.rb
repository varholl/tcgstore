class CreateStockEntries < ActiveRecord::Migration[8.0]
  def up
    create_table :stock_entries do |t|
      t.references :card, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.datetime :added_at, null: false

      t.timestamps
    end

    add_index :stock_entries, :added_at

    # Create one stock entry per existing card with quantity > 0
    Card.where("quantity > 0").find_each do |card|
      StockEntry.create!(
        card_id: card.id,
        quantity: card.quantity,
        added_at: card.last_stocked_at || Time.current
      )
    end
  end

  def down
    drop_table :stock_entries
  end
end
