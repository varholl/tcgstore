class AddFoilTypeToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :foil_type, :string
  end
end
