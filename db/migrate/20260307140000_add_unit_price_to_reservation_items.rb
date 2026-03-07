class AddUnitPriceToReservationItems < ActiveRecord::Migration[8.0]
  def change
    add_column :reservation_items, :unit_price, :decimal, precision: 10, scale: 2
  end
end
