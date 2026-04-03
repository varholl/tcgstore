class AddTrackingFieldsToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :tracking_number, :string
    add_column :reservations, :tracking_url, :string
  end
end
