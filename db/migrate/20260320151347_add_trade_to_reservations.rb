class AddTradeToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :trade, :boolean, default: false, null: false
  end
end
