class CreateCards < ActiveRecord::Migration[6.1]
  def change
    create_table :cards do |t|
      t.string :name
      t.string :edition
      t.string :condition
      t.string :language
      t.string :foil
      t.integer :quantity, default: 0
      t.string :collector_number
      t.decimal :purchase_price, precision: 10, scale: 2

      t.timestamps
    end

    add_index :cards, :name
    add_index :cards, :edition
  end
end
