class AddMetadataFieldsToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :colors, :string
    add_column :cards, :mana_cost, :string
    add_column :cards, :cmc, :decimal, precision: 5, scale: 1
    add_column :cards, :card_type, :string
    add_column :cards, :card_subtype, :string
    add_column :cards, :rarity, :string
  end
end
