class AddDeliveryFieldsToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :delivery_date, :date
    add_column :reservations, :delivery_location, :string
    add_column :reservations, :delivery_location_other, :string
  end
end
