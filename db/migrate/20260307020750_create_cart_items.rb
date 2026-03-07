class CreateCartItems < ActiveRecord::Migration[6.1]
  def change
    create_table :cart_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.integer :quantity, default: 1

      t.timestamps
    end

    add_index :cart_items, [:user_id, :card_id], unique: true
  end
end
