class AddShippingMethodToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :shipping_method, :string
    add_column :reservations, :pickup_location, :string
  end
end
