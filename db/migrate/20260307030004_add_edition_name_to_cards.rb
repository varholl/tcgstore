class AddEditionNameToCards < ActiveRecord::Migration[6.1]
  def change
    add_column :cards, :edition_name, :string
  end
end
