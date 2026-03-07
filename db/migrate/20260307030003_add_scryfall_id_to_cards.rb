class AddScryfallIdToCards < ActiveRecord::Migration[6.1]
  def change
    add_column :cards, :scryfall_id, :string
    add_index :cards, :scryfall_id
  end
end
