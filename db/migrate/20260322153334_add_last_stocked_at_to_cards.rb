class AddLastStockedAtToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :last_stocked_at, :datetime
    reversible do |dir|
      dir.up { execute "UPDATE cards SET last_stocked_at = created_at" }
    end
  end
end
